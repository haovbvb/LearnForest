import Foundation

/// 掌握状态只能由这里计算。页面不可以自己改 masteryLevel。
/// TODO(Sprint 3): 按 PRD §6.1 实现。浏览字卡不等于掌握；一次答对不等于稳定掌握。
protocol LearningService {
    var skeletonNote: String { get }
    func recordedMastery(of record: LearningRecord) -> MasteryLevel
}

struct UnimplementedLearningService: LearningService {
    var skeletonNote: String {
        "掌握状态机还没启用。浏览字卡不会记成已掌握。"
    }

    func recordedMastery(of record: LearningRecord) -> MasteryLevel {
        record.masteryLevel
    }
}
