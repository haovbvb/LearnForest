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
}

struct LearningSession: Codable, Equatable, Identifiable {
    var id: String
    var profileId: String
    var courseId: String
    var sessionType: SessionType
    var status: SessionStatus
    var currentIndex: Int
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

struct RewardCounts: Equatable {
    var stars: Int
    var stickers: Int
    var badges: Int

    static let zero = RewardCounts(stars: 0, stickers: 0, badges: 0)
}

struct DailySnapshot: Equatable {
    var studiedHanziIds: [String]
    var unfamiliarHanziIds: [String]
    var reviewSuggestionIds: [String]
    var activeDurationSeconds: Int

    static let empty = DailySnapshot(
        studiedHanziIds: [],
        unfamiliarHanziIds: [],
        reviewSuggestionIds: [],
        activeDurationSeconds: 0
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
