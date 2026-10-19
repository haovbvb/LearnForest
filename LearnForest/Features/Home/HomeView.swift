import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var navMode: ChildNavMode
    var onSelectLearnTab: () -> Void
    var onSelectCardsTab: () -> Void
    var onStartLearning: () -> Void
    var onOpenParent: () -> Void

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: ForestSpacing.large) {
                header
                if let bootstrapError = model.bootstrapError {
                    ForestCard(background: ForestPalette.gentleAlert.opacity(0.25)) {
                        Text(bootstrapError)
                            .font(.body)
                            .foregroundStyle(ForestPalette.ink)
                    }
                }
                if let contentError = model.contentError {
                    ForestCard(background: ForestPalette.sky.opacity(0.28)) {
                        Text(contentError)
                            .font(.body)
                            .foregroundStyle(ForestPalette.ink)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 14) {
                    PrimaryLearningButton(
                        title: model.primaryLearningTitle,
                        subtitle: model.primaryLearningSubtitle,
                        action: onStartLearning
                    )
                    Text(model.progressCaption)
                        .font(.title3)
                        .foregroundStyle(ForestPalette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: ForestSpacing.readingWidth)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                secondaryEntries
                rewardRow
                Text("课程在这台 iPad 上，没有网络也能看。")
                    .font(.callout)
                    .foregroundStyle(ForestPalette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(ForestSpacing.screen)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(ForestPalette.leaf)
                    Text(ProductIdentity.appName)
                        .font(.title.weight(.bold))
                        .foregroundStyle(ForestPalette.ink)
                }
                HStack(spacing: 8) {
                    Text(model.activeProfile?.displayName ?? "小朋友")
                    Text(model.activeProfile?.learningStage.title ?? "启蒙认字")
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ForestPalette.sky.opacity(0.35), in: Capsule())
            }
            Spacer()
            CornerIconButton(systemImage: "lock.fill", accessibilityLabel: "家长", action: onOpenParent)
        }
    }

    private var secondaryEntries: some View {
        HStack(spacing: 16) {
            learnEntry
            cardsEntry
        }
        .font(.title3.weight(.medium))
        .foregroundStyle(ForestPalette.inkSoft)
    }

    @ViewBuilder
    private var learnEntry: some View {
        if navMode == .homeCardsOnly {
            NavigationLink {
                LearnView()
            } label: {
                weakLabel(model.themeLine, systemImage: "text.book.closed.fill")
            }
        } else {
            Button(action: onSelectLearnTab) {
                weakLabel(model.themeLine, systemImage: "text.book.closed.fill")
            }
        }
    }

    @ViewBuilder
    private var cardsEntry: some View {
        if navMode == .homeCardsOnly {
            NavigationLink {
                MyCardsView()
            } label: {
                weakLabel("我的字卡", systemImage: "rectangle.on.rectangle.angled")
            }
        } else {
            Button(action: onSelectCardsTab) {
                weakLabel("我的字卡", systemImage: "rectangle.on.rectangle.angled")
            }
        }
    }

    private func weakLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
        .padding(.horizontal, 12)
        .background(ForestPalette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var rewardRow: some View {
        HStack(spacing: 18) {
            rewardItem("星星", count: model.rewardCounts.stars, symbol: "star.fill")
            rewardItem("贴纸", count: model.rewardCounts.stickers, symbol: "seal.fill")
            rewardItem("徽章", count: model.rewardCounts.badges, symbol: "rosette")
        }
        .font(.callout)
        .foregroundStyle(ForestPalette.inkSoft)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func rewardItem(_ title: String, count: Int, symbol: String) -> some View {
        Label("\(title) \(count)", systemImage: symbol)
    }
}
