import Foundation

struct LearningRecord: Codable, Equatable, Identifiable {
    var id: String
    var profileId: String
    var hanziId: String
    var firstLearnedAt: Date?
    var lastPracticedAt: Date?
    var correctCount: Int
    var incorrectCount: Int
    var masteryLevel: MasteryLevel
    var nextReviewAt: Date?
    var recognitionAccuracy: Double?
    var pronunciationRecognitionAccuracy: Double?
    var wordRecognitionAccuracy: Double?
    var contextRecognitionAccuracy: Double?
    var skillUpdatedAt: Date?
    var updatedAt: Date
    var syncStatus: String
    var schemaVersion: Int
    var deviceId: String?
    var deletedAt: Date?

    static func placeholderContact(
        profileId: String,
        hanziId: String,
        mastery: MasteryLevel,
        now: Date
    ) -> LearningRecord {
        LearningRecord(
            id: "\(profileId)#\(hanziId)",
            profileId: profileId,
            hanziId: hanziId,
            firstLearnedAt: now,
            lastPracticedAt: now,
            correctCount: 0,
            incorrectCount: 0,
            masteryLevel: mastery,
            nextReviewAt: nil,
            recognitionAccuracy: nil,
            pronunciationRecognitionAccuracy: nil,
            wordRecognitionAccuracy: nil,
            contextRecognitionAccuracy: nil,
            skillUpdatedAt: nil,
            updatedAt: now,
            syncStatus: SyncReservation.localOnly,
            schemaVersion: SyncReservation.schemaVersion,
            deviceId: nil,
            deletedAt: nil
        )
    }
}

struct LearningSession: Codable, Equatable, Identifiable {
    var id: String
    var profileId: String
    var courseId: String
    var sessionType: SessionType
    var status: SessionStatus
    var currentIndex: Int
    /// 练习题做到第几题。认字卡片仍用 currentIndex。
    var practiceIndex: Int
    var startedAt: Date
    var completedAt: Date?
    var activeDurationSeconds: Int
    var updatedAt: Date
    var syncStatus: String
    var schemaVersion: Int
    var deviceId: String?
    var deletedAt: Date?
}

struct AnswerRecord: Codable, Equatable, Identifiable {
    var id: String
    var sessionId: String
    var profileId: String
    var questionId: String
    /// 同一道题的一次出场。重复点击不得再次累计。Sprint 3 使用。
    var questionSessionId: String
    var targetHanziId: String
    var selectedAnswer: String
    var isCorrect: Bool
    var attemptIndex: Int
    var answeredAt: Date
    var syncStatus: String
    var schemaVersion: Int
    var deviceId: String?
    var deletedAt: Date?
}

struct RewardRecord: Codable, Equatable, Identifiable {
    var id: String
    var profileId: String
    var sourceType: String
    var sourceId: String
    var rewardType: RewardType
    var amount: Int
    var createdAt: Date
    var syncStatus: String
    var schemaVersion: Int
    var deviceId: String?
    var deletedAt: Date?
}

/// 某个档案在本地日历日里的有效学习秒数。只累计字卡和练习页的前台时间。
struct StudyTimeRecord: Codable, Equatable, Identifiable {
    var id: String
    var profileId: String
    var day: String
    var durationSeconds: Int
    var updatedAt: Date
    var syncStatus: String
    var schemaVersion: Int
    var deviceId: String?
    var deletedAt: Date?

    static func make(profileId: String, day: String, seconds: Int, now: Date) -> StudyTimeRecord {
        StudyTimeRecord(
            id: "\(profileId)#\(day)",
            profileId: profileId,
            day: day,
            durationSeconds: seconds,
            updatedAt: now,
            syncStatus: SyncReservation.localOnly,
            schemaVersion: SyncReservation.schemaVersion,
            deviceId: nil,
            deletedAt: nil
        )
    }
}

struct RewardGrant: Equatable {
    var stars: Int
    var stickers: Int
    var badges: Int

    static let zero = RewardGrant(stars: 0, stickers: 0, badges: 0)
}

enum RewardSource {
    static let hanziEmerging = "hanzi_emerging"
    static let hanziStable = "hanzi_stable"
    static let coursePractice = "course_practice"
}

enum AnswerSave: Equatable {
    case duplicate
    case saved(LearningRecord)
}

enum PracticeSubmitResult: Equatable {
    case duplicate
    case saved
    case failed(String)
}

struct PracticeReport: Equatable {
    var correctAnswers: Int
    var answerCount: Int
    var emergingCharacters: [String]
    var stableCharacters: [String]
    var reviewCharacters: [String]
    var grant: RewardGrant

    static let empty = PracticeReport(
        correctAnswers: 0,
        answerCount: 0,
        emergingCharacters: [],
        stableCharacters: [],
        reviewCharacters: [],
        grant: .zero
    )
}

struct RewardCounts: Equatable {
    var stars: Int
    var stickers: Int
    var badges: Int

    static let zero = RewardCounts(stars: 0, stickers: 0, badges: 0)
}

struct DailySnapshot: Equatable {
    var studiedHanziIds: [String]
    var unfamiliarHanziIds: [String]
    /// 从还不熟、待复习里挑出的少数几个，最多 3 个。
    var reviewSuggestionIds: [String]
    var activeDurationSeconds: Int
    /// 今天新写入的奖励。和结果页「这次新得到」用同一张奖励表，已经发过的不会再算进去。
    var rewardsToday: RewardGrant

    static let empty = DailySnapshot(
        studiedHanziIds: [],
        unfamiliarHanziIds: [],
        reviewSuggestionIds: [],
        activeDurationSeconds: 0,
        rewardsToday: .zero
    )
}

enum DurationText {
    static func friendly(seconds: Int) -> String {
        if seconds <= 0 { return "0 分钟" }
        if seconds < 60 { return "不到 1 分钟" }
        return "\(seconds / 60) 分钟"
    }

    static func limitLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "关闭" }
        return "\(minutes) 分钟"
    }
}
