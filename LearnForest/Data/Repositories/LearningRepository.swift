import Foundation
import GRDB

/// 学习记录只读查询。答题结算、掌握状态和发奖留到 Sprint 3，避免半成品被页面误用。
protocol LearningStoring: AnyObject {
    func hasInProgressSession(profileId: String) throws -> Bool
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
        try queue.read { db in
            try LearningSession
                .filter(Column("profileId") == profileId && Column("status") == SessionStatus.inProgress.rawValue)
                .fetchCount(db) > 0
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
