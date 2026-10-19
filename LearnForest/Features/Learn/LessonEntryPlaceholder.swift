import SwiftUI

/// TODO(Sprint 2): 学习准备、汉字卡片、中断恢复、时长到点温和结束。
/// TODO(Sprint 3): 听音找图、看字找图、汉字图片配对、结果页与星星。
struct LessonEntryPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ZStack {
                ForestPalette.cream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.primaryLearningTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(ForestPalette.ink)
                    Text("今天的学习流程还在制作。这里不会开始真正的课，也不会记掌握。")
                        .font(.title3)
                        .foregroundStyle(ForestPalette.inkSoft)
                    ForestCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("接下来会有")
                                .font(.title3.weight(.semibold))
                            Text("学习准备 → 汉字卡片 → 三种练习 → 学习结果")
                            Text(model.learningService.skeletonNote)
                                .foregroundStyle(ForestPalette.inkSoft)
                            if let todo = model.contentPackage?.exercises.todo {
                                Text(todo)
                                    .foregroundStyle(ForestPalette.inkSoft)
                            }
                        }
                        .font(.body)
                        .foregroundStyle(ForestPalette.ink)
                    }
                    Spacer()
                    Button("回到首页") { dismiss() }
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .foregroundStyle(ForestPalette.ink)
                }
                .padding(32)
                .frame(maxWidth: 760)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
