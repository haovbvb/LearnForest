import SwiftUI

private enum CardFilter: String, CaseIterable, Identifiable {
    case all
    case notStarted
    case learning
    case needsReview
    case emerging
    case stable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .notStarted: "未学习"
        case .learning: "学习中"
        case .needsReview: "待复习"
        case .emerging: "初步掌握"
        case .stable: "稳定掌握"
        }
    }

    var mastery: MasteryLevel? {
        switch self {
        case .all: nil
        case .notStarted: .notStarted
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
                NavigationLink {
                    ReviewSessionView()
                } label: {
                    HStack {
                        Text(reviewTitle)
                            .font(.title3.weight(.bold))
                        Spacer()
                        Text(reviewSubtitle)
                            .font(.body)
                    }
                    .foregroundStyle(ForestPalette.ink)
                    .padding(.horizontal, ForestSpacing.medium)
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                    .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CardFilter.allCases) { item in
                            Button {
                                filter = item
                            } label: {
                                Text(chipTitle(item))
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
                                NavigationLink {
                                    HanziDetailView(hanziId: item.id)
                                } label: {
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
                                .buttonStyle(.plain)
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
            "课程包里还没有字。"
        case .notStarted:
            "这些字都已经打开过了。"
        case .learning:
            "还没有学过的字。从首页「今日学习」认一个字，就会出现在这里。"
        case .needsReview:
            "还没有待复习的字。稳定掌握后再答错，会来到这里。错得比较多的字也可以从「去复习」再看。"
        case .emerging, .stable:
            "还没有「\(filter.title)」的字。练习答对够次数之后，才会出现在这里。"
        }
    }

    private func chipTitle(_ item: CardFilter) -> String {
        let count = count(for: item)
        return "\(item.title) \(count)"
    }

    private func count(for item: CardFilter) -> Int {
        let hanzi = model.contentPackage?.hanzi ?? []
        return hanzi.filter { character in
            guard let mastery = item.mastery else { return true }
            return model.mastery(for: character.id) == mastery
        }.count
    }

    private var reviewTitle: String {
        if let open = model.openReview {
            let ids = ReviewQueue.ids(in: open.reviewTargets)
            if !ids.isEmpty, open.practiceIndex < ids.count {
                return "继续复习"
            }
        }
        return "去复习"
    }

    private var reviewSubtitle: String {
        let waiting = ReviewQueue.pick(records: model.learningRecords).count
        if reviewTitle == "继续复习" { return "接着上一轮" }
        if waiting == 0 { return "现在没有要复习的字" }
        return "这一轮 \(min(waiting, ReviewQueue.roundSize)) 个"
    }
}
