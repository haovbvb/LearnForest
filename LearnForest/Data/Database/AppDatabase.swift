import Foundation
import GRDB

/// SQLite 入口。页面不要直接拿 queue，走 Repository。
final class AppDatabase {
    let queue: DatabaseQueue

    private init(queue: DatabaseQueue) throws {
        self.queue = queue
        try SchemaMigration.migrator.migrate(queue)
    }

    static func onDisk() throws -> AppDatabase {
        let url = try databaseFileURL()
        var configuration = Configuration()
        configuration.label = "LearnForest"
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        return try AppDatabase(queue: queue)
    }

    static func inMemory() throws -> AppDatabase {
        try AppDatabase(queue: try DatabaseQueue())
    }

    /// Application Support，不放进用户可见的「文件」目录。
    static func databaseFileURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("LearnForest", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("learnforest.sqlite")
    }
}
