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

/// 课程包清单校验。只看本地 JSON，不访问网络。
enum ManifestCheck {
    static func validate(
        manifest: ContentManifest,
        themes: [Theme],
        courses: [Course],
        hanzi: [Hanzi],
        links: [CourseHanziLink],
        appVersion: String
    ) throws {
        if manifest.contentPackageId.trimmingCharacters(in: .whitespaces).isEmpty {
            throw ContentPackageError.inconsistent("课程包没有 contentPackageId。")
        }
        if manifest.productLine != ProductIdentity.productLineID {
            throw ContentPackageError.inconsistent("这个课程包不是识字森林的中文包。")
        }
        if manifest.schemaVersion != 1 {
            throw ContentPackageError.inconsistent("认不出的课程包结构版本。")
        }
        if manifest.contentVersion < 1 || manifest.assetsManifestVersion < 1 {
            throw ContentPackageError.inconsistent("课程包版本号无效。")
        }
        if manifest.title.trimmingCharacters(in: .whitespaces).isEmpty {
            throw ContentPackageError.inconsistent("课程包没有标题。")
        }
        if manifest.remoteUpdate.enabled {
            throw ContentPackageError.inconsistent("V1.0 不应开启远程课程更新。")
        }
        if !VersionCompare.isSupported(minimum: manifest.minimumAppVersion, current: appVersion) {
            throw ContentPackageError.inconsistent("这个课程包需要更新的 App 才能打开。已装的旧内容会留着。")
        }
        if manifest.themeIds.isEmpty || themes.isEmpty {
            throw ContentPackageError.inconsistent("课程包里没有主题。")
        }
        try requireUnique(themes.map(\.id), label: "主题")
        try requireUnique(courses.map(\.id), label: "课程")
        try requireUnique(hanzi.map(\.id), label: "汉字")

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
        let courseIds = Set(courses.map(\.id))
        for course in courses {
            if !themeIds.contains(course.themeId) {
                throw ContentPackageError.inconsistent("课程 \(course.id) 的主题不存在。")
            }
            for id in course.hanziIds where !hanziIds.contains(id) {
                throw ContentPackageError.inconsistent("课程 \(course.id) 引用了不存在的汉字 \(id)。")
            }
            let linked = links.filter { $0.courseId == course.id }.map(\.hanziId)
            if Set(linked) != Set(course.hanziIds) {
                throw ContentPackageError.inconsistent("课程 \(course.id) 的汉字关联和课程文件不一致。")
            }
        }
        for link in links {
            if !courseIds.contains(link.courseId) || !hanziIds.contains(link.hanziId) {
                throw ContentPackageError.inconsistent("汉字关联指向了不存在的课或字。")
            }
        }
    }

    private static func requireUnique(_ ids: [String], label: String) throws {
        var seen = Set<String>()
        for id in ids {
            if id.isEmpty || !seen.insert(id).inserted {
                throw ContentPackageError.inconsistent("\(label) ID 重复或是空的。")
            }
        }
    }
}

enum VersionCompare {
    /// 课程包要求的最低版本不高于当前 App 时，才可以装。
    static func isSupported(minimum: String, current: String) -> Bool {
        compare(minimum, to: current) != .orderedDescending
    }

    static func compare(_ lhs: String, to rhs: String) -> ComparisonResult {
        let left = parts(lhs)
        let right = parts(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
