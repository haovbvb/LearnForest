import Foundation

/// 只在 App 包内找图和标准录音。找不到就当资源还没进包，不访问网络。
enum LocalAssetLocator {
    private static let audioExtensions = ["m4a", "mp3", "wav", "caf", "aac"]
    private static let imageExtensions = ["png", "jpg", "jpeg", "webp", "heic"]

    static func hasAudio(assetId: String, bundle: Bundle = .main) -> Bool {
        audioURL(assetId: assetId, bundle: bundle) != nil
    }

    static func hasImage(assetId: String, bundle: Bundle = .main) -> Bool {
        imageURL(assetId: assetId, bundle: bundle) != nil
    }

    static func audioURL(assetId: String, bundle: Bundle = .main) -> URL? {
        fileURL(assetId: assetId, extensions: audioExtensions, bundle: bundle)
    }

    static func imageURL(assetId: String, bundle: Bundle = .main) -> URL? {
        fileURL(assetId: assetId, extensions: imageExtensions, bundle: bundle)
    }

    private static func fileURL(assetId: String, extensions: [String], bundle: Bundle) -> URL? {
        let trimmed = assetId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = bundle.url(forResource: trimmed, withExtension: nil),
           FileManager.default.fileExists(atPath: direct.path),
           !direct.hasDirectoryPath {
            return direct
        }

        let subdirectories: [String?] = [
            BundledCoursePack.subdirectory + "/" + BundledCoursePack.resourceName,
            BundledCoursePack.resourceName,
            BundledCoursePack.subdirectory,
            nil
        ]
        for ext in extensions {
            for subdirectory in subdirectories {
                if let url = bundle.url(forResource: trimmed, withExtension: ext, subdirectory: subdirectory) {
                    return url
                }
            }
        }

        guard let folder = coursePackFolder(bundle: bundle) else { return nil }
        for ext in extensions {
            let url = folder.appendingPathComponent("\(trimmed).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func coursePackFolder(bundle: Bundle) -> URL? {
        if let nested = bundle.url(
            forResource: BundledCoursePack.resourceName,
            withExtension: nil,
            subdirectory: BundledCoursePack.subdirectory
        ) {
            return nested
        }
        return bundle.url(forResource: BundledCoursePack.resourceName, withExtension: nil)
    }
}
