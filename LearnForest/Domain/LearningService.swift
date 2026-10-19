import Foundation

/// 掌握状态只能由这里计算。页面不可以自己改 masteryLevel。
/// 轻量验收规则（对应 PRD 的掌握分级，不是完整复习算法）：
/// 看字卡最多到「学习中」；一次答对不会变成掌握；
/// 答对至少 2 次且多于答错，才是初步掌握；
/// 答对至少 4 次且比答错至少多 3 次，才是稳定掌握；
/// 稳定掌握后再答错，变成待复习，不扣已有奖励。
protocol LearningService {
    var skeletonNote: String { get }
    func recordedMastery(of record: LearningRecord) -> MasteryLevel
    func masteryAfterCharacterContact(existing: MasteryLevel?) -> MasteryLevel
    func masteryAfterAnswer(
        previous: MasteryLevel,
        correctCount: Int,
        incorrectCount: Int,
        lastWasCorrect: Bool
    ) -> MasteryLevel
}

enum MasteryRules {
    static func afterCharacterContact(existing: MasteryLevel?) -> MasteryLevel {
        switch existing {
        case .some(let level) where level != .notStarted && level != .learning:
            level
        default:
            .learning
        }
    }

    static func afterAnswer(
        previous: MasteryLevel,
        correctCount: Int,
        incorrectCount: Int,
        lastWasCorrect: Bool
    ) -> MasteryLevel {
        if !lastWasCorrect {
            switch previous {
            case .stable:
                return .needsReview
            case .needsReview:
                return .needsReview
            case .emerging, .learning, .notStarted:
                return .learning
            }
        }
        if correctCount >= 4 && correctCount >= incorrectCount + 3 {
            return .stable
        }
        if previous == .stable {
            return .stable
        }
        if correctCount >= 2 && correctCount > incorrectCount {
            return .emerging
        }
        if previous == .emerging {
            return .emerging
        }
        return .learning
    }
}

struct ForestLearningService: LearningService {
    var skeletonNote: String {
        "看字卡只记「学习中」。练习答对两次以上才会初步掌握，稳定掌握要更多次答对。答错不惩罚。"
    }

    func recordedMastery(of record: LearningRecord) -> MasteryLevel {
        record.masteryLevel
    }

    func masteryAfterCharacterContact(existing: MasteryLevel?) -> MasteryLevel {
        MasteryRules.afterCharacterContact(existing: existing)
    }

    func masteryAfterAnswer(
        previous: MasteryLevel,
        correctCount: Int,
        incorrectCount: Int,
        lastWasCorrect: Bool
    ) -> MasteryLevel {
        MasteryRules.afterAnswer(
            previous: previous,
            correctCount: correctCount,
            incorrectCount: incorrectCount,
            lastWasCorrect: lastWasCorrect
        )
    }
}
