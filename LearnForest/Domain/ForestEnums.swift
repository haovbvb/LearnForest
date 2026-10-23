import Foundation

enum AgeStage: String, Codable, CaseIterable, Identifiable, Equatable {
    case age3to4 = "age_3_4"
    case age4to5 = "age_4_5"
    case age5to6 = "age_5_6"
    case age6to7 = "age_6_7"
    case age7to8 = "age_7_8"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .age3to4: "3～4 岁"
        case .age4to5: "4～5 岁"
        case .age5to6: "5～6 岁"
        case .age6to7: "6～7 岁"
        case .age7to8: "7～8 岁"
        }
    }
}

/// 年龄决定推荐起点，不锁死课程。修改阶段不得清除学习记录。
enum LearningStage: String, Codable, CaseIterable, Identifiable, Equatable {
    case enlightenment
    case basicReading = "basic_reading"
    case literacyPlus = "literacy_plus"
    case readingPractice = "reading_practice"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .enlightenment: "启蒙认字"
        case .basicReading: "基础认读"
        case .literacyPlus: "识字进阶"
        case .readingPractice: "阅读练习"
        }
    }
}

enum PinyinMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case hidden
    case showWeak = "show_weak"
    case show

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hidden: "不显示拼音"
        case .showWeak: "弱化显示拼音"
        case .show: "显示拼音"
        }
    }
}

/// 二选一，不可同时出现底栏和另一套大卡片导航。
enum ChildNavMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case tabWithHero = "tab_with_hero"
    case homeCardsOnly = "home_cards_only"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tabWithHero: "底栏 + 首页大按钮"
        case .homeCardsOnly: "仅首页大卡片"
        }
    }
}

enum MasteryLevel: String, Codable, CaseIterable, Identifiable, Equatable {
    case notStarted = "not_started"
    case learning
    case emerging
    case stable
    case needsReview = "needs_review"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notStarted: "未学习"
        case .learning: "学习中"
        case .emerging: "初步掌握"
        case .stable: "稳定掌握"
        case .needsReview: "待复习"
        }
    }
}

enum RewardType: String, Codable, CaseIterable, Identifiable, Equatable {
    case star
    case sticker
    case badge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .star: "星星"
        case .sticker: "贴纸"
        case .badge: "徽章"
        }
    }
}

enum SessionType: String, Codable, Equatable {
    case newLearning = "new_learning"
    case review
}

enum SessionStatus: String, Codable, Equatable {
    case inProgress = "in_progress"
    case completed
    case interrupted
}

enum ExerciseType {
    static let listenAndSelectImage = "listen_and_select_image"
    static let characterToImage = "character_to_image"
    static let characterImageMatching = "character_image_matching"
    /// 可选，V1.0 骨架不实现。
    static let wordBuilding = "word_building"
    static let similarCharacter = "similar_character"

    static let coreV1 = [listenAndSelectImage, characterToImage, characterImageMatching]

    static func title(for raw: String) -> String {
        switch raw {
        case listenAndSelectImage: "听音找图"
        case characterToImage: "看字找图"
        case characterImageMatching: "汉字图片配对"
        case wordBuilding: "组词"
        case similarCharacter: "形近字"
        default: raw
        }
    }
}

/// V1.0 不上传。字段留在本地行上，供以后的同步使用。
enum SyncReservation {
    static let localOnly = "local_only"
    static let schemaVersion = 1
}
