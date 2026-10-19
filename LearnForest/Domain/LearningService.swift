import Foundation

/// 掌握状态只能由这里计算。页面不可以自己改 masteryLevel。
/// TODO(Sprint 3): 按 PRD §6.1 实现。浏览字卡不等于掌握；一次答对不等于稳定掌握。
protocol LearningService {
    var skeletonNote: String { get }
    func recordedMastery(of record: LearningRecord) -> MasteryLevel
    /// 认字只把「未学习」记成「学习中」。不升到初步掌握或稳定掌握，也不降级。
    func masteryAfterCharacterContact(existing: MasteryLevel?) -> MasteryLevel
}

struct UnimplementedLearningService: LearningService {
    var skeletonNote: String {
        "翻过的字会记成「学习中」，不会记成掌握。换一个档案看不到这些进度。到点只是休息，不扣奖励。"
    }

    func recordedMastery(of record: LearningRecord) -> MasteryLevel {
        record.masteryLevel
    }

    func masteryAfterCharacterContact(existing: MasteryLevel?) -> MasteryLevel {
        switch existing {
        case .some(let level) where level != .notStarted && level != .learning:
            level
        default:
            .learning
        }
    }
}
