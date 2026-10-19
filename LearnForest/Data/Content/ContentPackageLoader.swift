import Foundation

enum ContentPackageError: LocalizedError {
    case packageNotFound
    case missingFile(String)
    case decode(String, Error)
    case inconsistent(String)

    var errorDescription: String? {
        switch self {
        case .packageNotFound:
            "没有找到本地课程包。已安装的课应该能离线打开。"
        case .missingFile(let name):
            "课程包缺少 \(name)。"
        case .decode(let name, let error):
            "课程包 \(name) 读不出来：\(error.localizedDescription)"
        case .inconsistent(let message):
            message
        }
    }
}

enum ContentPackageLoader {
    static func loadBundledPackage(bundle: Bundle = .main) throws -> ContentPackage {
        let root = try packageRoot(bundle: bundle)
        let manifest: ContentManifest = try decode(ContentManifest.self, name: "manifest.json", in: root)
        let themes: [Theme] = try decode([Theme].self, name: "themes.json", in: root)
        let courses: [Course] = try decode([Course].self, name: "courses.json", in: root)
        let hanzi: [Hanzi] = try decode([Hanzi].self, name: "hanzi.json", in: root)
        let links: [CourseHanziLink] = try decode([CourseHanziLink].self, name: "course_hanzi.json", in: root)
        let exercises: ExerciseCatalogPlaceholder = try decode(
            ExerciseCatalogPlaceholder.self,
            name: "exercises_placeholder.json",
            in: root
        )
        try validate(
            manifest: manifest,
            themes: themes,
            courses: courses,
            hanzi: hanzi,
            links: links
        )
        return ContentPackage(
            manifest: manifest,
            themes: themes,
            courses: courses,
            hanzi: hanzi,
            courseHanzi: links,
            exercises: exercises
        )
    }

    private static func packageRoot(bundle: Bundle) throws -> URL {
        let candidates = [
            bundle.url(forResource: BundledCoursePack.resourceName, withExtension: nil),
            bundle.url(
                forResource: BundledCoursePack.resourceName,
                withExtension: nil,
                subdirectory: BundledCoursePack.subdirectory
            )
        ]
        if let url = candidates.compactMap({ $0 }).first {
            return url
        }
        throw ContentPackageError.packageNotFound
    }

    private static func decode<T: Decodable>(_ type: T.Type, name: String, in root: URL) throws -> T {
        let url = root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ContentPackageError.missingFile(name)
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as ContentPackageError {
            throw error
        } catch {
            throw ContentPackageError.decode(name, error)
        }
    }

    private static func validate(
        manifest: ContentManifest,
        themes: [Theme],
        courses: [Course],
        hanzi: [Hanzi],
        links: [CourseHanziLink]
    ) throws {
        guard manifest.productLine == ProductIdentity.productLineID else {
            throw ContentPackageError.inconsistent("这个课程包不是识字森林的中文包。")
        }
        guard manifest.remoteUpdate.enabled == false else {
            throw ContentPackageError.inconsistent("V1.0 不应开启远程课程更新。")
        }
        let themeIds = Set(themes.map(\.id))
        for id in manifest.themeIds where !themeIds.contains(id) {
            throw ContentPackageError.inconsistent("清单里的主题 \(id) 不在主题文件中。")
        }
        if courses.count != manifest.plannedCourseCount {
            throw ContentPackageError.inconsistent("课程数量和清单不一致。")
        }
        if hanzi.count != manifest.sampleHanziCount {
            throw ContentPackageError.inconsistent("样例字数量和清单不一致。")
        }
        let hanziIds = Set(hanzi.map(\.id))
        for course in courses {
            for id in course.hanziIds where !hanziIds.contains(id) {
                throw ContentPackageError.inconsistent("课程 \(course.id) 引用了不存在的汉字 \(id)。")
            }
            let linked = links.filter { $0.courseId == course.id }.map(\.hanziId)
            if Set(linked) != Set(course.hanziIds) {
                throw ContentPackageError.inconsistent("课程 \(course.id) 的汉字关联和课程文件不一致。")
            }
        }
    }
}
