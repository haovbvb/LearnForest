import Foundation
import GRDB

enum ProfileError: LocalizedError, Equatable {
    case missing
    case lastProfile

    var errorDescription: String? {
        switch self {
        case .missing:
            "没有找到这个档案。"
        case .lastProfile:
            "至少保留一个档案。"
        }
    }
}

/// 本地多档案。进度、奖励、时长都按 profileId 分开，这里只负责档案本身。
protocol ChildProfileStoring: AnyObject {
    func list() throws -> [ChildProfile]
    func active() throws -> ChildProfile?
    func ensureDefaultProfile() throws
    func create(nickname: String?, ageStage: AgeStage, learningStage: LearningStage) throws -> ChildProfile
    func rename(id: String, nickname: String) throws
    func activate(id: String) throws
    func save(_ profile: ChildProfile) throws
    func delete(id: String) throws
}

final class ChildProfileRepository: ChildProfileStoring {
    private let queue: DatabaseQueue

    init(queue: DatabaseQueue) {
        self.queue = queue
    }

    func list() throws -> [ChildProfile] {
        try queue.read { db in
            try ChildProfile.order(Column("createdAt").asc).fetchAll(db)
        }
    }

    func active() throws -> ChildProfile? {
        try queue.read { db in
            try ChildProfile.filter(Column("isActive") == true).fetchOne(db)
        }
    }

    func ensureDefaultProfile() throws {
        try queue.write { db in
            let profiles = try ChildProfile.order(Column("createdAt").asc).fetchAll(db)
            if profiles.isEmpty {
                try ChildProfile.makeDefault(isActive: true).insert(db)
                return
            }
            if !profiles.contains(where: \.isActive) {
                var first = profiles[0]
                first.isActive = true
                first.updatedAt = Date()
                try first.update(db)
            }
        }
    }

    func create(nickname: String?, ageStage: AgeStage, learningStage: LearningStage) throws -> ChildProfile {
        try queue.write { db in
            let count = try ChildProfile.fetchCount(db)
            if count > 0 {
                try db.execute(sql: "UPDATE childProfile SET isActive = 0")
            }
            var profile = ChildProfile.makeDefault(isActive: true)
            let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            profile.nickname = trimmed.isEmpty ? "小朋友 \(count + 1)" : trimmed
            profile.ageStage = ageStage
            profile.learningStage = learningStage
            try profile.insert(db)
            return profile
        }
    }

    func rename(id: String, nickname: String) throws {
        try queue.write { db in
            guard var profile = try ChildProfile.fetchOne(db, key: id) else {
                throw ProfileError.missing
            }
            let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.nickname = trimmed.isEmpty ? "小朋友" : trimmed
            profile.updatedAt = Date()
            try profile.update(db)
        }
    }

    func activate(id: String) throws {
        try queue.write { db in
            guard var profile = try ChildProfile.fetchOne(db, key: id) else {
                throw ProfileError.missing
            }
            try db.execute(sql: "UPDATE childProfile SET isActive = 0")
            profile.isActive = true
            profile.updatedAt = Date()
            try profile.update(db)
        }
    }

    func save(_ profile: ChildProfile) throws {
        try queue.write { db in
            guard try ChildProfile.fetchOne(db, key: profile.id) != nil else {
                throw ProfileError.missing
            }
            var copy = profile
            copy.updatedAt = Date()
            if copy.isActive {
                try db.execute(
                    sql: "UPDATE childProfile SET isActive = 0 WHERE id <> ?",
                    arguments: [copy.id]
                )
            }
            try copy.update(db)
        }
    }

    /// 硬删除该档案下的学习记录、答题、会话和奖励。不删除课程包。
    /// 调用方必须先做家长验证和二次确认。V1.0 没有云备份。
    func delete(id: String) throws {
        try queue.write { db in
            let count = try ChildProfile.fetchCount(db)
            if count <= 1 {
                throw ProfileError.lastProfile
            }
            guard try ChildProfile.fetchOne(db, key: id) != nil else {
                throw ProfileError.missing
            }
            let sessionIds = try LearningSession
                .filter(Column("profileId") == id)
                .fetchAll(db)
                .map(\.id)
            if !sessionIds.isEmpty {
                try AnswerRecord
                    .filter(sessionIds.contains(Column("sessionId")))
                    .deleteAll(db)
            }
            try LearningSession.filter(Column("profileId") == id).deleteAll(db)
            try LearningRecord.filter(Column("profileId") == id).deleteAll(db)
            try RewardRecord.filter(Column("profileId") == id).deleteAll(db)
            _ = try ChildProfile.deleteOne(db, key: id)

            if try ChildProfile.filter(Column("isActive") == true).fetchCount(db) == 0 {
                if var fallback = try ChildProfile.order(Column("updatedAt").desc).fetchOne(db) {
                    fallback.isActive = true
                    fallback.updatedAt = Date()
                    try fallback.update(db)
                }
            }
        }
    }
}
