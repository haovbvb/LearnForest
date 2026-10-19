import SwiftUI

private enum CardFilter: String, CaseIterable, Identifiable {
    case all
    case learning
    case needsReview
    case emerging
    case stable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .learning: "学习中"
        case .needsReview: "待复习"
        case .emerging: "初步掌握"
        case .stable: "稳定掌握"
        }
    }

    var mastery: MasteryLevel? {
        switch self {
        case .all: nil
        case .learning: .learning
        case .needsReview: .needsReview
        case .emerging: .emerging
        case .stable: .stable
        }
    }
}

struct MyCardsView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: CardFilter = .all

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: ForestSpacing.medium) {
                Text("我的字卡")
                    .font(ForestType.screenTitle)
                    .foregroundStyle(ForestPalette.ink)
                Text("现在是「\(model.activeProfile?.displayName ?? "小朋友")」")
                    .font(.title3)
                    .foregroundStyle(ForestPalette.inkSoft)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CardFilter.allCases) { item in
                            Button {
                                filter = item
                            } label: {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: ForestSpacing.minTouch)
                                    .background(
                                        filter == item ? ForestPalette.leaf.opacity(0.3) : ForestPalette.card,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(ForestPalette.ink)
                            }
                        }
                    }
                }
                Text(model.learningService.skeletonNote)
                    .font(.callout)
                    .foregroundStyle(ForestPalette.inkSoft)
                ScrollView {
                    if visibleHanzi.isEmpty {
                        ForestCard {
                            Text(emptyMessage)
                                .font(.title3)
                                .foregroundStyle(ForestPalette.ink)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: ForestSpacing.medium)], spacing: ForestSpacing.medium) {
                            ForEach(visibleHanzi) { item in
                                HanziCard(
                                    character: item.character,
                                    pinyin: item.pinyin,
                                    showsPinyin: model.showsPinyin(),
                                    pinyinIsSecondary: model.pinyinIsSecondary(),
                                    definition: nil,
                                    statusTitle: model.mastery(for: item.id).title,
                                    compact: true
                                )
                            }
                        }
                    }
                }
            }
            .padding(ForestSpacing.screen)
        }
        .navigationTitle("我的字卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var visibleHanzi: [Hanzi] {
        let hanzi = model.contentPackage?.hanzi ?? []
        return hanzi.filter { item in
            guard let mastery = filter.mastery else { return true }
            return model.mastery(for: item.id) == mastery
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .all:
            "还没有样例字。"
        case .learning:
            "还没有学过的字。从首页「今日学习」认一个字，就会出现在这里。"
        case .needsReview, .emerging, .stable:
            "还没有「\(filter.title)」的字。练习做好之前，不会出现在这里。"
        }
    }
}
