import Foundation

/// 同一台 iPad 上的本地儿童档案。V1.0 至少支持 2 条，不做云同步。
struct ChildProfile: Codable, Equatable, Identifiable {
    var id: String
    var nickname: String?
    var ageStage: AgeStage
    var learningStage: LearningStage
    var learningGoal: String?
    var difficultyPreference: String
    var pinyinMode: PinyinMode
    /// 单次上限（分钟）。nil 表示关闭。
    var sessionDurationLimitMinutes: Int?
    /// 每日上限（分钟）。nil 表示关闭。
    var dailyDurationLimitMinutes: Int?
    var quietMode: Bool
    var quietModeAllowSoftAutoPronounce: Bool
    var childNavMode: ChildNavMode
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var deletedAt: Date?
    /// 预留。V1.0 恒为 local_only，不上传。
    var syncStatus: String
    var schemaVersion: Int
    /// 预留。V1.0 不生成用于云端的设备标识。
    var deviceId: String?

    var displayName: String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "小朋友" : trimmed
    }

    static func makeDefault(isActive: Bool, now: Date = Date()) -> ChildProfile {
        ChildProfile(
            id: UUID().uuidString,
            nickname: "小朋友",
            ageStage: .age3to4,
            learningStage: .enlightenment,
            learningGoal: nil,
            difficultyPreference: "recommended",
            pinyinMode: .showWeak,
            // 默认时长待产品确认（10 或 15）。骨架先关闭，设置项仍可选择。
            sessionDurationLimitMinutes: nil,
            dailyDurationLimitMinutes: nil,
            quietMode: false,
            quietModeAllowSoftAutoPronounce: false,
            childNavMode: .tabWithHero,
            createdAt: now,
            updatedAt: now,
            isActive: isActive,
            deletedAt: nil,
            syncStatus: SyncReservation.localOnly,
            schemaVersion: SyncReservation.schemaVersion,
            deviceId: nil
        )
    }
}
