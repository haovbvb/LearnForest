import Foundation
import GRDB

/// 本地库结构。课程正文在 JSON 课程包里，不进这些表。
/// 新迁移只追加，不改已发布的 v1 内容。失败时 GRDB 停在上一版本，原库文件还在。
enum SchemaMigration {
    static let schemaVersion = 1

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial") { db in
            try createChildProfile(db)
            try createLearningRecord(db)
            try createLearningSession(db)
            try createAnswerRecord(db)
            try createRewardRecord(db)
            try createContentInstallState(db)
        }
        migrator.registerMigration("v2_study_time") { db in
            try createStudyTime(db)
        }
        migrator.registerMigration("v3_practice") { db in
            try db.alter(table: "learningSession") { table in
                table.add(column: "practiceIndex", .integer).notNull().defaults(to: 0)
            }
            try db.alter(table: "answerRecord") { table in
                table.add(column: "profileId", .text).notNull().defaults(to: "")
            }
            try db.execute(
                sql: """
                UPDATE answerRecord
                SET profileId = (
                    SELECT profileId FROM learningSession
                    WHERE learningSession.id = answerRecord.sessionId
                )
                WHERE profileId = ''
                """
            )
            try db.create(
                index: "answerRecord_profile",
                on: "answerRecord",
                columns: ["profileId"]
            )
        }
        migrator.registerMigration("v4_review_targets") { db in
            try db.alter(table: "learningSession") { table in
                table.add(column: "reviewTargets", .text).notNull().defaults(to: "")
            }
        }
        return migrator
    }

    private static func createChildProfile(_ db: Database) throws {
        try db.create(table: "childProfile") { table in
            table.primaryKey("id", .text)
            table.column("nickname", .text)
            table.column("ageStage", .text).notNull()
            table.column("learningStage", .text).notNull()
            table.column("learningGoal", .text)
            table.column("difficultyPreference", .text).notNull()
            table.column("pinyinMode", .text).notNull()
            table.column("sessionDurationLimitMinutes", .integer)
            table.column("dailyDurationLimitMinutes", .integer)
            table.column("quietMode", .boolean).notNull().defaults(to: false)
            table.column("quietModeAllowSoftAutoPronounce", .boolean).notNull().defaults(to: false)
            table.column("childNavMode", .text).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
            table.column("isActive", .boolean).notNull().defaults(to: false)
            table.column("deletedAt", .datetime)
            // §9.4 预留。V1.0 不实现账号与同步。
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("schemaVersion", .integer).notNull().defaults(to: schemaVersion)
            table.column("deviceId", .text)
        }
        try db.create(index: "childProfile_isActive", on: "childProfile", columns: ["isActive"])
    }

    private static func createLearningRecord(_ db: Database) throws {
        try db.create(table: "learningRecord") { table in
            table.primaryKey("id", .text)
            table.column("profileId", .text).notNull()
            table.column("hanziId", .text).notNull()
            table.column("firstLearnedAt", .datetime)
            table.column("lastPracticedAt", .datetime)
            table.column("correctCount", .integer).notNull().defaults(to: 0)
            table.column("incorrectCount", .integer).notNull().defaults(to: 0)
            table.column("masteryLevel", .text).notNull()
            table.column("nextReviewAt", .datetime)
            table.column("recognitionAccuracy", .double)
            table.column("pronunciationRecognitionAccuracy", .double)
            table.column("wordRecognitionAccuracy", .double)
            table.column("contextRecognitionAccuracy", .double)
            table.column("skillUpdatedAt", .datetime)
            table.column("updatedAt", .datetime).notNull()
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("schemaVersion", .integer).notNull().defaults(to: schemaVersion)
            table.column("deviceId", .text)
            table.column("deletedAt", .datetime)
        }
        try db.create(
            index: "learningRecord_profile_hanzi",
            on: "learningRecord",
            columns: ["profileId", "hanziId"],
            unique: true
        )
    }

    private static func createLearningSession(_ db: Database) throws {
        try db.create(table: "learningSession") { table in
            table.primaryKey("id", .text)
            table.column("profileId", .text).notNull()
            table.column("courseId", .text).notNull()
            table.column("sessionType", .text).notNull()
            table.column("status", .text).notNull()
            table.column("currentIndex", .integer).notNull().defaults(to: 0)
            table.column("startedAt", .datetime).notNull()
            table.column("completedAt", .datetime)
            table.column("activeDurationSeconds", .integer).notNull().defaults(to: 0)
            table.column("updatedAt", .datetime).notNull()
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("schemaVersion", .integer).notNull().defaults(to: schemaVersion)
            table.column("deviceId", .text)
            table.column("deletedAt", .datetime)
        }
        try db.create(
            index: "learningSession_profile_status_updated",
            on: "learningSession",
            columns: ["profileId", "status", "updatedAt"]
        )
    }

    private static func createAnswerRecord(_ db: Database) throws {
        try db.create(table: "answerRecord") { table in
            table.primaryKey("id", .text)
            table.column("sessionId", .text).notNull()
            table.column("questionId", .text).notNull()
            table.column("questionSessionId", .text).notNull()
            table.column("targetHanziId", .text).notNull()
            table.column("selectedAnswer", .text).notNull()
            table.column("isCorrect", .boolean).notNull()
            table.column("attemptIndex", .integer).notNull()
            table.column("answeredAt", .datetime).notNull()
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("schemaVersion", .integer).notNull().defaults(to: schemaVersion)
            table.column("deviceId", .text)
            table.column("deletedAt", .datetime)
        }
        try db.create(
            index: "answerRecord_session_question",
            on: "answerRecord",
            columns: ["sessionId", "questionId"]
        )
        // 同一次出场的同一次尝试只能有一行。
        try db.create(
            index: "answerRecord_question_attempt",
            on: "answerRecord",
            columns: ["questionSessionId", "attemptIndex"],
            unique: true
        )
    }

    private static func createRewardRecord(_ db: Database) throws {
        try db.create(table: "rewardRecord") { table in
            table.primaryKey("id", .text)
            table.column("profileId", .text).notNull()
            table.column("sourceType", .text).notNull()
            table.column("sourceId", .text).notNull()
            table.column("rewardType", .text).notNull()
            table.column("amount", .integer).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("schemaVersion", .integer).notNull().defaults(to: schemaVersion)
            table.column("deviceId", .text)
            table.column("deletedAt", .datetime)
        }
        // 同一来源不重复发同一种奖励。没有货币类型。
        try db.create(
            index: "rewardRecord_source",
            on: "rewardRecord",
            columns: ["profileId", "sourceType", "sourceId", "rewardType"],
            unique: true
        )
    }

    /// 已安装课程包的版本记录。远程下载留到 V1.3：失败必须留下旧包。
    private static func createContentInstallState(_ db: Database) throws {
        try db.create(table: "contentInstallState") { table in
            table.primaryKey("id", .text)
            table.column("contentPackageId", .text).notNull()
            table.column("contentVersion", .integer).notNull()
            table.column("schemaVersion", .integer).notNull()
            table.column("assetsManifestVersion", .integer).notNull()
            table.column("minimumAppVersion", .text).notNull()
            table.column("installedAt", .datetime).notNull()
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("deviceId", .text)
        }
    }

    /// 按档案和本地日历日记有效学习秒数。远程同步仍不上传。
    private static func createStudyTime(_ db: Database) throws {
        try db.create(table: "studyTime") { table in
            table.primaryKey("id", .text)
            table.column("profileId", .text).notNull()
            table.column("day", .text).notNull()
            table.column("durationSeconds", .integer).notNull().defaults(to: 0)
            table.column("updatedAt", .datetime).notNull()
            table.column("syncStatus", .text).notNull().defaults(to: SyncReservation.localOnly)
            table.column("schemaVersion", .integer).notNull().defaults(to: schemaVersion)
            table.column("deviceId", .text)
            table.column("deletedAt", .datetime)
        }
        try db.create(
            index: "studyTime_profile_day",
            on: "studyTime",
            columns: ["profileId", "day"],
            unique: true
        )
    }
}
