import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var navMode: ChildNavMode
    var onSelectLearnTab: () -> Void
    var onSelectCardsTab: () -> Void
    var onStartLearning: () -> Void
    var onOpenParent: () -> Void

    private let dailyCharacterGoal = 8

    var body: some View {
        ZStack {
            Image("home_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, ForestSpacing.screen)
                    .padding(.top, 10)

                Spacer(minLength: 20)

                heroRow
                    .padding(.horizontal, ForestSpacing.screen)

                Spacer(minLength: 16)

                themePanel
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ForestPalette.leaf)
                    Text(ProductIdentity.appName)
                        .font(.title.weight(.bold))
                        .foregroundStyle(ForestPalette.leaf)
                }
                Text("— \(ProductIdentity.tagline)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer(minLength: 12)
            Button(action: onOpenParent) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .foregroundStyle(ForestPalette.sky)
                    Text(model.activeProfile?.displayName ?? "小朋友")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ForestPalette.ink)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ForestPalette.card, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
            .accessibilityLabel("家长与档案")
            CornerIconButton(systemImage: "gearshape.fill", accessibilityLabel: "设置", action: onOpenParent)
        }
    }

    private var heroRow: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer(minLength: 0)
                PrimaryLearningButton(
                    title: model.hasInProgressSession ? "继续学习" : "开始学习",
                    subtitle: dailyProgressLine,
                    showsSunIcon: true,
                    compactPill: true,
                    action: onStartLearning
                )
                Spacer(minLength: 0)
            }
            productRail
        }
        .frame(maxWidth: .infinity)
    }

    private var productRail: some View {
        VStack(alignment: .trailing, spacing: 10) {
            productChip(title: "汉字森林", symbol: "leaf.fill", color: ForestPalette.leaf, enabled: true)
            productChip(title: "英语森林", symbol: "star.fill", color: ForestPalette.sky, enabled: false)
            productChip(title: "更多精彩", symbol: "heart.fill", color: ForestPalette.coral, enabled: false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("产品线：汉字森林可用，英语森林与更多精彩即将开放")
    }

    private func productChip(title: String, symbol: String, color: Color, enabled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ForestPalette.ink.opacity(enabled ? 1 : 0.55))
            if !enabled {
                Text("即将")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.82, blue: 0.62),
                    Color(red: 0.86, green: 0.70, blue: 0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .opacity(enabled ? 1 : 0.85)
    }

    private var dailyProgressLine: String {
        let studied = model.dailySnapshot.studiedHanziIds.count
        if model.hasInProgressSession, let title = model.continueCourseTitle {
            return "接着「\(title)」 · 今日 \(studied) / \(dailyCharacterGoal)"
        }
        return "今日已学 \(studied) / \(dailyCharacterGoal)"
    }

    private var themePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let bootstrapError = model.bootstrapError {
                ForestCard(background: ForestPalette.coral.opacity(0.28)) {
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

            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(ForestPalette.leaf)
                Text("选择你喜欢的场景")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
            }

            if let package = model.contentPackage {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(package.themesSorted) { theme in
                        themeCardLink(theme)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ForestCard {
                    Text("主题还没有准备好。")
                        .foregroundStyle(ForestPalette.ink)
                }
            }

        }
        .padding(.horizontal, ForestSpacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func themeCardLink(_ theme: Theme) -> some View {
        NavigationLink {
            CourseListView(themeId: theme.id)
        } label: {
            themeCard(theme)
        }
        .buttonStyle(.plain)
    }

    private func themeCard(_ theme: Theme) -> some View {
        let accent = ForestPalette.themeAccent(themeId: theme.id)
        return VStack(alignment: .leading, spacing: 0) {
            Image(themeCoverName(theme.id))
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(theme.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                    .lineLimit(1)
                Text(theme.summary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ForestPalette.inkSoft)
                    .lineLimit(1)
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(accent, in: Circle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForestPalette.themeCardBackground(themeId: theme.id))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: accent.opacity(0.18), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.title)，\(theme.summary)")
    }

    private func themeCoverName(_ themeId: String) -> String {
        switch themeId {
        case "theme_animals":
            return "item1"
        case "theme_family":
            return "item2"
        case "theme_nature":
            return "item3"
        default:
            return "item1"
        }
    }
}
