import SwiftUI

enum LessonRestReason: Equatable {
    case sessionLimit
    case dailyLimit
    case charactersSeen
}

/// 到点或认完字后的休息页。不结算掌握，不发贴纸。
struct LessonRestView: View {
    @Environment(AppModel.self) private var model
    let reason: LessonRestReason
    let courseTitle: String
    let seenCount: Int
    let totalCount: Int

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: ForestSpacing.large) {
                Text(title)
                    .font(ForestType.screenTitle)
                    .foregroundStyle(ForestPalette.ink)
                Text(message)
                    .font(.title3)
                    .foregroundStyle(ForestPalette.ink)
                ForestCard {
                    VStack(alignment: .leading, spacing: ForestSpacing.small) {
                        Text(courseTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(ForestPalette.ink)
                        Text("看到第 \(min(seenCount, totalCount)) / \(totalCount) 个字")
                            .font(.title3)
                            .foregroundStyle(ForestPalette.inkSoft)
                        Text("今天学了 \(DurationText.friendly(seconds: model.dailySnapshot.activeDurationSeconds))")
                            .font(.title3)
                            .foregroundStyle(ForestPalette.leaf)
                        Text("练习、掌握结算和贴纸还没做，这次不发奖励。")
                            .font(.body)
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                Button("先离开") {
                    model.dismissLesson()
                }
                .font(.title3.weight(.bold))
                .foregroundStyle(ForestPalette.ink)
                .frame(maxWidth: .infinity, minHeight: ForestSpacing.heroMinHeight * 0.7)
                .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.heroRadius, style: .continuous))
            }
            .padding(ForestSpacing.screen)
            .frame(maxWidth: ForestSpacing.readingWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var title: String {
        switch reason {
        case .sessionLimit: "这次先到这里"
        case .dailyLimit: "今天先到这里"
        case .charactersSeen: "这节课的字先认完了"
        }
    }

    private var message: String {
        switch reason {
        case .sessionLimit:
            "休息一下再来就好。没有惩罚，过一会儿还可以继续认这些字。"
        case .dailyLimit:
            "今天的学习时间够了。可以回去看看别的，明天再学也不会受罚。"
        case .charactersSeen:
            "先记住看到哪一个字。听音找图那些练习还没接上，所以不会记成学会。"
        }
    }
}
