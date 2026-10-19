import Foundation
import GRDB

/// 认字记下「学习中」。练习答题会升级掌握，并在做完后发放星星、贴纸、徽章。
protocol LearningStoring: AnyObject {
    func hasInProgressSession(profileId: String) throws -> Bool
    func inProgressSession(profileId: String) throws -> LearningSession?
    func sessions(profileId: String) throws -> [LearningSession]
    func records(profileId: String) throws -> [LearningRecord]
    func beginCharacterLesson(profileId: String, courseId: String, now: Date) throws -> LearningSession
    func noteCharacterContact(profileId: String, hanziId: String, mastery: MasteryLevel, now: Date) throws
    func updateIndex(sessionId: String, currentIndex: Int, now: Date) throws
    func updatePracticeIndex(sessionId: String, practiceIndex: Int, now: Date) throws
    func recordAnswer(
        profileId: String,
        sessionId: String,
        questionId: String,
        questionSessionId: String,
        targetHanziId: String,
        selectedAnswer: String,
        isCorrect: Bool,
        attemptIndex: Int,
        now: Date
    ) throws -> AnswerSave
    func finishPractice(
        profileId: String,
        sessionId: String,
        courseId: String,
        hanziIds: [String],
        questionCount: Int,
        characterNames: [String: String],
        now: Date
    ) throws -> PracticeReport
    func beginReview(profileId: String, targetIds: [String], now: Date) throws -> LearningSession?
    func completeReview(sessionId: String, questionCount: Int, now: Date) throws
    func addStudyTime(profileId: String, sessionId: String, seconds: Int, now: Date) throws
    func rewardCounts(profileId: String) throws -> RewardCounts
    func dailySnapshot(profileId: String, now: Date) throws -> DailySnapshot
    /// 清掉该档案的学习记录、答题、进度、奖励和有效时长。不删档案，不删课程包。
    func clearLearningData(profileId: String) throws
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
                .filter(
                    Column("profileId") == profileId
                        && Column("status") == SessionStatus.inProgress.rawValue
                        && Column("sessionType") != SessionType.review.rawValue
                )
                .order(Column("updatedAt").desc)
                .fetchOne(db)
        }
    }

    func sessions(profileId: String) throws -> [LearningSession] {
        try queue.read { db in
            try LearningSession
                .filter(Column("profileId") == profileId)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    func records(profileId: String) throws -> [LearningRecord] {
        try queue.read { db in
            try LearningRecord
                .filter(Column("profileId") == profileId)
                .fetchAll(db)
        }
    }

    /// 同一课接着上次的字。别的进行中的课改成中断，序号留着，方便以后再打开。
    func beginCharacterLesson(profileId: String, courseId: String, now: Date) throws -> LearningSession {
        try queue.write { db in
            let all = try LearningSession
                .filter(Column("profileId") == profileId)
                .fetchAll(db)
            let forCourse = all.filter { $0.courseId == courseId }
            let candidate = forCourse.filter { $0.status == .inProgress }.max { $0.updatedAt < $1.updatedAt }
                ?? forCourse.filter { $0.status == .interrupted }.max { $0.updatedAt < $1.updatedAt }

            for var session in all where session.status == .inProgress && session.id != candidate?.id {
                session.status = .interrupted
                session.updatedAt = now
                try session.update(db)
            }

            if var existing = candidate {
                existing.status = .inProgress
                existing.updatedAt = now
                try existing.update(db)
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
                practiceIndex: 0,
                reviewTargets: "",
                updatedAt: now,
                syncStatus: SyncReservation.localOnly,
                schemaVersion: SyncReservation.schemaVersion,
                deviceId: nil,
                deletedAt: nil
            )
            try session.insert(db)
            return session
        }
    }

    /// 只记录「接触过」。掌握等级由 LearningService 决定，这里不升到初步掌握。
    func noteCharacterContact(profileId: String, hanziId: String, mastery: MasteryLevel, now: Date) throws {
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

    func addStudyTime(profileId: String, sessionId: String, seconds: Int, now: Date) throws {
        guard seconds > 0 else { return }
        try queue.write { db in
            if var session = try LearningSession.fetchOne(db, key: sessionId) {
                session.activeDurationSeconds += seconds
                session.updatedAt = now
                try session.update(db)
            }
            let day = StudyDay.key(for: now)
            let id = "\(profileId)#\(day)"
            if var row = try StudyTimeRecord.fetchOne(db, key: id) {
                row.durationSeconds += seconds
                row.updatedAt = now
                try row.update(db)
            } else {
                try StudyTimeRecord.make(profileId: profileId, day: day, seconds: seconds, now: now).insert(db)
            }
        }
    }

    /// 不打断正在认的课。有未做完的复习就接着那一轮，做完的才另开一轮。
    func beginReview(profileId: String, targetIds: [String], now: Date) throws -> LearningSession? {
        try queue.write { db in
            let rows = try LearningSession
                .filter(Column("profileId") == profileId && Column("sessionType") == SessionType.review.rawValue)
                .fetchAll(db)
            let candidate = rows.filter { $0.status == .inProgress }.max { $0.updatedAt < $1.updatedAt }
                ?? rows.filter { $0.status == .interrupted }.max { $0.updatedAt < $1.updatedAt }
            if var existing = candidate {
                let stored = ReviewQueue.ids(in: existing.reviewTargets)
                let unfinished = !stored.isEmpty && existing.practiceIndex < stored.count
                if unfinished {
                    existing.status = .inProgress
                    existing.updatedAt = now
                    try existing.update(db)
                    return existing
                }
                if stored.isEmpty && !targetIds.isEmpty {
                    existing.reviewTargets = ReviewQueue.joined(targetIds)
                    existing.practiceIndex = 0
                    existing.status = .inProgress
                    existing.updatedAt = now
                    try existing.update(db)
                    return existing
                }
                if existing.status != .completed {
                    existing.status = .completed
                    existing.completedAt = now
                    existing.updatedAt = now
                    try existing.update(db)
                }
            }
            guard !targetIds.isEmpty else { return nil }
            let session = LearningSession(
                id: UUID().uuidString,
                profileId: profileId,
                courseId: ReviewQueue.courseId,
                sessionType: .review,
                status: .inProgress,
                currentIndex: 0,
                startedAt: now,
                completedAt: nil,
                activeDurationSeconds: 0,
                practiceIndex: 0,
                reviewTargets: ReviewQueue.joined(targetIds),
                updatedAt: now,
                syncStatus: SyncReservation.localOnly,
                schemaVersion: SyncReservation.schemaVersion,
                deviceId: nil,
                deletedAt: nil
            )
            try session.insert(db)
            return session
        }
    }

    func completeReview(sessionId: String, questionCount: Int, now: Date) throws {
        try queue.write { db in
            guard var session = try LearningSession.fetchOne(db, key: sessionId) else { return }
            session.status = .completed
            session.practiceIndex = questionCount
            session.completedAt = now
            session.updatedAt = now
            try session.update(db)
        }
    }

    func updatePracticeIndex(sessionId: String, practiceIndex: Int, now: Date) throws {
        try queue.write { db in
            guard var session = try LearningSession.fetchOne(db, key: sessionId) else { return }
            session.practiceIndex = practiceIndex
            session.updatedAt = now
            try session.update(db)
        }
    }

    func recordAnswer(
        profileId: String,
        sessionId: String,
        questionId: String,
        questionSessionId: String,
        targetHanziId: String,
        selectedAnswer: String,
        isCorrect: Bool,
        attemptIndex: Int,
        now: Date
    ) throws -> AnswerSave {
        try queue.write { db in
            let already = try AnswerRecord
                .filter(Column("questionSessionId") == questionSessionId && Column("attemptIndex") == attemptIndex)
                .fetchOne(db)
            if already != nil {
                return .duplicate
            }
            let answer = AnswerRecord(
                id: UUID().uuidString,
                sessionId: sessionId,
                profileId: profileId,
                questionId: questionId,
                questionSessionId: questionSessionId,
                targetHanziId: targetHanziId,
                selectedAnswer: selectedAnswer,
                isCorrect: isCorrect,
                attemptIndex: attemptIndex,
                answeredAt: now,
                syncStatus: SyncReservation.localOnly,
                schemaVersion: SyncReservation.schemaVersion,
                deviceId: nil,
                deletedAt: nil
            )
            do {
                try answer.insert(db)
            } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                return .duplicate
            }
            let record = try upsertMastery(
                db: db,
                profileId: profileId,
                hanziId: targetHanziId,
                isCorrect: isCorrect,
                now: now
            )
            return .saved(record)
        }
    }

    func finishPractice(
        profileId: String,
        sessionId: String,
        courseId: String,
        hanziIds: [String],
        questionCount: Int,
        characterNames: [String: String],
        now: Date
    ) throws -> PracticeReport {
        try queue.write { db in
            if var session = try LearningSession.fetchOne(db, key: sessionId) {
                session.practiceIndex = questionCount
                session.updatedAt = now
                try session.update(db)
            }
            let records = try LearningRecord
                .filter(Column("profileId") == profileId)
                .fetchAll(db)
                .filter { hanziIds.contains($0.hanziId) }
            var grant = RewardGrant.zero
            for record in records {
                if record.masteryLevel == .emerging || record.masteryLevel == .stable {
                    if try insertReward(
                        db: db,
                        profileId: profileId,
                        sourceType: RewardSource.hanziEmerging,
                        sourceId: record.hanziId,
                        rewardType: .star,
                        now: now
                    ) {
                        grant.stars += 1
                    }
                }
                if record.masteryLevel == .stable {
                    if try insertReward(
                        db: db,
                        profileId: profileId,
                        sourceType: RewardSource.hanziStable,
                        sourceId: record.hanziId,
                        rewardType: .badge,
                        now: now
                    ) {
                        grant.badges += 1
                    }
                }
            }
            if try insertReward(
                db: db,
                profileId: profileId,
                sourceType: RewardSource.coursePractice,
                sourceId: courseId,
                rewardType: .sticker,
                now: now
            ) {
                grant.stickers += 1
            }
            let answers = try AnswerRecord
                .filter(Column("profileId") == profileId && Column("sessionId") == sessionId)
                .fetchAll(db)
            return PracticeReport(
                correctAnswers: answers.filter(\.isCorrect).count,
                answerCount: answers.count,
                emergingCharacters: records.filter { $0.masteryLevel == .emerging }.map { characterNames[$0.hanziId] ?? $0.hanziId },
                stableCharacters: records.filter { $0.masteryLevel == .stable }.map { characterNames[$0.hanziId] ?? $0.hanziId },
                reviewCharacters: records.filter { $0.masteryLevel == .needsReview }.map { characterNames[$0.hanziId] ?? $0.hanziId },
                grant: grant
            )
        }
    }

    private func upsertMastery(
        db: Database,
        profileId: String,
        hanziId: String,
        isCorrect: Bool,
        now: Date
    ) throws -> LearningRecord {
        var record = try LearningRecord
            .filter(Column("profileId") == profileId && Column("hanziId") == hanziId)
            .fetchOne(db)
            ?? LearningRecord.placeholderContact(
                profileId: profileId,
                hanziId: hanziId,
                mastery: .learning,
                now: now
            )
        let previous = record.masteryLevel
        if isCorrect {
            record.correctCount += 1
        } else {
            record.incorrectCount += 1
        }
        record.masteryLevel = MasteryRules.afterAnswer(
            previous: previous,
            correctCount: record.correctCount,
            incorrectCount: record.incorrectCount,
            lastWasCorrect: isCorrect
        )
        let total = record.correctCount + record.incorrectCount
        record.recognitionAccuracy = total == 0 ? nil : Double(record.correctCount) / Double(total)
        record.lastPracticedAt = now
        record.updatedAt = now
        if record.masteryLevel == .needsReview {
            record.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: now)
        } else if record.masteryLevel == .stable || record.masteryLevel == .emerging {
            record.nextReviewAt = nil
        }
        try record.save(db)
        return record
    }

    private func insertReward(
        db: Database,
        profileId: String,
        sourceType: String,
        sourceId: String,
        rewardType: RewardType,
        now: Date
    ) throws -> Bool {
        let reward = RewardRecord(
            id: "\(profileId)#\(sourceType)#\(sourceId)#\(rewardType.rawValue)",
            profileId: profileId,
            sourceType: sourceType,
            sourceId: sourceId,
            rewardType: rewardType,
            amount: 1,
            createdAt: now,
            syncStatus: SyncReservation.localOnly,
            schemaVersion: SyncReservation.schemaVersion,
            deviceId: nil,
            deletedAt: nil
        )
        do {
            try reward.insert(db)
            return true
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
            return false
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

    func clearLearningData(profileId: String) throws {
        try queue.write { db in
            try Self.deleteOwnedData(profileId: profileId, db: db)
        }
    }

    /// 档案删除和「清除学习数据」共用这一段，避免两边删的范围不一致。
    static func deleteOwnedData(profileId: String, db: Database) throws {
        let sessionIds = try LearningSession
            .filter(Column("profileId") == profileId)
            .fetchAll(db)
            .map(\.id)
        if !sessionIds.isEmpty {
            try AnswerRecord
                .filter(sessionIds.contains(Column("sessionId")))
                .deleteAll(db)
        }
        try AnswerRecord.filter(Column("profileId") == profileId).deleteAll(db)
        try LearningSession.filter(Column("profileId") == profileId).deleteAll(db)
        try LearningRecord.filter(Column("profileId") == profileId).deleteAll(db)
        try RewardRecord.filter(Column("profileId") == profileId).deleteAll(db)
        try StudyTimeRecord.filter(Column("profileId") == profileId).deleteAll(db)
    }

    func dailySnapshot(profileId: String, now: Date) throws -> DailySnapshot {
        try queue.read { db in
            let start = Calendar.current.startOfDay(for: now)
            let records = try LearningRecord.filter(Column("profileId") == profileId).fetchAll(db)
            let studied = records
                .filter { ($0.lastPracticedAt ?? .distantPast) >= start }
                .sorted { ($0.lastPracticedAt ?? .distantPast) < ($1.lastPracticedAt ?? .distantPast) }
            let unfamiliar = records
                .filter { record in
                    record.masteryLevel == .needsReview || record.incorrectCount > record.correctCount
                }
                .sorted { lhs, rhs in
                    let leftReview = lhs.masteryLevel == .needsReview
                    let rightReview = rhs.masteryLevel == .needsReview
                    if leftReview != rightReview { return leftReview }
                    let leftGap = lhs.incorrectCount - lhs.correctCount
                    let rightGap = rhs.incorrectCount - rhs.correctCount
                    if leftGap != rightGap { return leftGap > rightGap }
                    let leftDate = lhs.nextReviewAt ?? .distantFuture
                    let rightDate = rhs.nextReviewAt ?? .distantFuture
                    if leftDate != rightDate { return leftDate < rightDate }
                    return lhs.hanziId < rhs.hanziId
                }
            let rewards = try RewardRecord.filter(Column("profileId") == profileId).fetchAll(db)
            var grant = RewardGrant.zero
            for row in rewards where row.createdAt >= start {
                switch row.rewardType {
                case .star: grant.stars += row.amount
                case .sticker: grant.stickers += row.amount
                case .badge: grant.badges += row.amount
                }
            }
            let day = StudyDay.key(for: now)
            let seconds = try StudyTimeRecord
                .filter(Column("profileId") == profileId && Column("day") == day)
                .fetchOne(db)?
                .durationSeconds ?? 0
            return DailySnapshot(
                studiedHanziIds: studied.map(\.hanziId),
                unfamiliarHanziIds: unfamiliar.map(\.hanziId),
                reviewSuggestionIds: unfamiliar.prefix(3).map(\.hanziId),
                activeDurationSeconds: seconds,
                rewardsToday: grant
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
