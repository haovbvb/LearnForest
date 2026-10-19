import Foundation

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
        try ManifestCheck.validate(
            manifest: manifest,
            themes: themes,
            courses: courses,
            hanzi: hanzi,
            links: links,
            appVersion: ProductIdentity.marketingVersion
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
}
