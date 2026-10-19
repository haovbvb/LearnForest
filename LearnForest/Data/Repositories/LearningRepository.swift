import Foundation
import GRDB

/// 占位预习会写下「学习中」和课程序号。答题、掌握升级和发奖留到 Sprint 3。
protocol LearningStoring: AnyObject {
    func hasInProgressSession(profileId: String) throws -> Bool
    func inProgressSession(profileId: String) throws -> LearningSession?
    func records(profileId: String) throws -> [LearningRecord]
    func startOrResume(profileId: String, courseId: String, now: Date) throws -> LearningSession
    func touchForPlaceholder(profileId: String, hanziId: String, mastery: MasteryLevel, now: Date) throws
    func updateIndex(sessionId: String, currentIndex: Int, now: Date) throws
    func rewardCounts(profileId: String) throws -> RewardCounts
    func dailySnapshot(profileId: String, now: Date) throws -> DailySnapshot
    func noteContentInstall(_ manifest: ContentManifest) throws
    func installedContentVersion(packageId: String) throws -> Int?
}

final class LearningRepository: LearningStoring {
    private let queue: DatabaseQueue

    init(queue: DatabaseQueue) {
        self.queue = queue
    }

    func hasInProgressSession(profileId: String) throws -> Bool {
        try inProgressSession(profileId: profileId) != nil
    }

    func inProgressSession(profileId: String) throws -> LearningSession? {
        try queue.read { db in
            try LearningSession
                .filter(Column("profileId") == profileId && Column("status") == SessionStatus.inProgress.rawValue)
                .order(Column("updatedAt").desc)
                .fetchOne(db)
        }
    }

    func records(profileId: String) throws -> [LearningRecord] {
        try queue.read { db in
            try LearningRecord
                .filter(Column("profileId") == profileId)
                .fetchAll(db)
        }
    }

    func startOrResume(profileId: String, courseId: String, now: Date) throws -> LearningSession {
        if let existing = try inProgressSession(profileId: profileId) {
            return existing
        }
        let session = LearningSession(
            id: UUID().uuidString,
            profileId: profileId,
            courseId: courseId,
            sessionType: .newLearning,
            status: .inProgress,
            currentIndex: 0,
            startedAt: now,
            completedAt: nil,
            activeDurationSeconds: 0,
            updatedAt: now,
            syncStatus: SyncReservation.localOnly,
            schemaVersion: SyncReservation.schemaVersion,
            deviceId: nil,
            deletedAt: nil
        )
        try queue.write { db in
            try session.insert(db)
        }
        return session
    }

    /// 只记录「接触过」。掌握等级由 LearningService 决定，这里不升到初步掌握。
    func touchForPlaceholder(profileId: String, hanziId: String, mastery: MasteryLevel, now: Date) throws {
        try queue.write { db in
            if var existing = try LearningRecord
                .filter(Column("profileId") == profileId && Column("hanziId") == hanziId)
                .fetchOne(db) {
                if existing.firstLearnedAt == nil {
                    existing.firstLearnedAt = now
                }
                existing.lastPracticedAt = now
                existing.masteryLevel = mastery
                existing.updatedAt = now
                try existing.update(db)
            } else {
                try LearningRecord.placeholderContact(
                    profileId: profileId,
                    hanziId: hanziId,
                    mastery: mastery,
                    now: now
                ).insert(db)
            }
        }
    }

    func updateIndex(sessionId: String, currentIndex: Int, now: Date) throws {
        try queue.write { db in
            guard var session = try LearningSession.fetchOne(db, key: sessionId) else { return }
            session.currentIndex = currentIndex
            session.updatedAt = now
            try session.update(db)
        }
    }

    func rewardCounts(profileId: String) throws -> RewardCounts {
        try queue.read { db in
            let rows = try RewardRecord.filter(Column("profileId") == profileId).fetchAll(db)
            var counts = RewardCounts.zero
            for row in rows {
                switch row.rewardType {
                case .star: counts.stars += row.amount
                case .sticker: counts.stickers += row.amount
                case .badge: counts.badges += row.amount
                }
            }
            return counts
        }
    }

    func dailySnapshot(profileId: String, now: Date) throws -> DailySnapshot {
        try queue.read { db in
            let start = Calendar.current.startOfDay(for: now)
            let records = try LearningRecord.filter(Column("profileId") == profileId).fetchAll(db)
            let studied = records.filter { ($0.lastPracticedAt ?? .distantPast) >= start }
            let unfamiliar = records.filter { record in
                record.masteryLevel == .needsReview || record.incorrectCount > record.correctCount
            }
            let suggestions = records
                .filter { $0.masteryLevel == .needsReview || $0.nextReviewAt != nil }
                .prefix(5)
            let sessions = try LearningSession.filter(Column("profileId") == profileId).fetchAll(db)
            let seconds = sessions
                .filter { $0.startedAt >= start }
                .reduce(0) { $0 + $1.activeDurationSeconds }
            return DailySnapshot(
                studiedHanziIds: studied.map(\.hanziId),
                unfamiliarHanziIds: unfamiliar.map(\.hanziId),
                reviewSuggestionIds: suggestions.map(\.hanziId),
                activeDurationSeconds: seconds
            )
        }
    }

    func noteContentInstall(_ manifest: ContentManifest) throws {
        try queue.write { db in
            let record = ContentInstallRecord(
                id: manifest.contentPackageId,
                contentPackageId: manifest.contentPackageId,
                contentVersion: manifest.contentVersion,
                schemaVersion: manifest.schemaVersion,
                assetsManifestVersion: manifest.assetsManifestVersion,
                minimumAppVersion: manifest.minimumAppVersion,
                installedAt: Date(),
                syncStatus: SyncReservation.localOnly,
                deviceId: nil
            )
            try record.save(db)
        }
    }

    func installedContentVersion(packageId: String) throws -> Int? {
        try queue.read { db in
            try ContentInstallRecord.fetchOne(db, key: packageId)?.contentVersion
        }
    }
}
