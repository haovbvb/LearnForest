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
            VStack(alignment: .leading, spacing: 16) {
                Text("我的字卡")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CardFilter.allCases) { item in
                            Button {
                                filter = item
                            } label: {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 60)
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
                    if filter == .all, let hanzi = model.contentPackage?.hanzi, !hanzi.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                            ForEach(hanzi) { item in
                                ForestCard {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.character)
                                            .font(.system(size: 48, weight: .medium, design: .rounded))
                                        if model.activeProfile?.pinyinMode != .hidden {
                                            Text(item.pinyin)
                                                .foregroundStyle(ForestPalette.inkSoft)
                                        }
                                        Text(MasteryLevel.notStarted.title)
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(ForestPalette.leaf)
                                    }
                                    .foregroundStyle(ForestPalette.ink)
                                }
                            }
                        }
                    } else {
                        ForestCard {
                            Text(emptyMessage)
                                .font(.title3)
                                .foregroundStyle(ForestPalette.ink)
                        }
                    }
                }
            }
            .padding(32)
        }
        .navigationTitle("我的字卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var emptyMessage: String {
        switch filter {
        case .all:
            "还没有样例字。"
        case .learning, .needsReview, .emerging, .stable:
            "还没有「\(filter.title)」的字。学完以后才会出现在这里。"
        }
    }
}
