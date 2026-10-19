import Foundation
import GRDB

extension ChildProfile: FetchableRecord, PersistableRecord {
    static let databaseTableName = "childProfile"
}

extension LearningRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "learningRecord"
}

extension LearningSession: FetchableRecord, PersistableRecord {
    static let databaseTableName = "learningSession"
}

extension AnswerRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "answerRecord"
}

extension RewardRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "rewardRecord"
}

struct ContentInstallRecord: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "contentInstallState"

    var id: String
    var contentPackageId: String
    var contentVersion: Int
    var schemaVersion: Int
    var assetsManifestVersion: Int
    var minimumAppVersion: String
    var installedAt: Date
    var syncStatus: String
    var deviceId: String?
}
