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
            ForestPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: ForestSpacing.large) {
                    header
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
                    heroBanner
                    themeSection
                    Text("课程在这台 iPad 上，没有网络也能看。")
                        .font(.callout)
                        .foregroundStyle(ForestPalette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, ForestSpacing.medium)
                }
                .padding(ForestSpacing.screen)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
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

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackdrop
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            HStack(alignment: .bottom, spacing: 20) {
                heroMascotPlaceholder
                    .frame(width: 160, height: 160)
                    .padding(.leading, 20)
                    .padding(.bottom, 16)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 16) {
                    productRail
                    PrimaryLearningButton(
                        title: model.hasInProgressSession ? "继续学习" : "开始学习",
                        subtitle: dailyProgressLine,
                        showsSunIcon: true,
                        compactPill: true,
                        action: onStartLearning
                    )
                }
                .padding(.trailing, 22)
                .padding(.bottom, 22)
            }
        }
        .frame(minHeight: 260)
        .shadow(color: ForestPalette.leaf.opacity(0.18), radius: 16, y: 8)
    }

    private var heroBackdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.82, blue: 0.95),
                Color(red: 0.62, green: 0.86, blue: 0.58),
                Color(red: 0.42, green: 0.70, blue: 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(ForestPalette.sun.opacity(0.85))
                .frame(width: 72, height: 72)
                .blur(radius: 0.5)
                .padding(28)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            Ellipse()
                .fill(Color(red: 0.22, green: 0.55, blue: 0.78).opacity(0.35))
                .frame(height: 70)
                .offset(y: 10)
                .accessibilityHidden(true)
        }
    }

    private var heroMascotPlaceholder: some View {
        ZStack {
            Circle()
                .fill(ForestPalette.cream.opacity(0.9))
                .frame(width: 140, height: 140)
            VStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ForestPalette.sun)
                Image(systemName: "leaf.fill")
                    .font(.title)
                    .foregroundStyle(ForestPalette.leaf)
            }
        }
        .accessibilityLabel("森林插画占位，正式插画稍后替换")
    }

    private var productRail: some View {
        VStack(alignment: .trailing, spacing: 8) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ForestPalette.card.opacity(enabled ? 0.95 : 0.72), in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private var dailyProgressLine: String {
        let studied = model.dailySnapshot.studiedHanziIds.count
        if model.hasInProgressSession, let title = model.continueCourseTitle {
            return "接着「\(title)」 · 今日 \(studied) / \(dailyCharacterGoal)"
        }
        return "今日已学 \(studied) / \(dailyCharacterGoal)"
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("选择你喜欢的主题")
                .font(.title2.weight(.bold))
                .foregroundStyle(ForestPalette.ink)
            if let package = model.contentPackage {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(package.themesSorted) { theme in
                        themeCardLink(theme, package: package)
                    }
                }
            } else {
                ForestCard {
                    Text("主题还没有准备好。")
                        .foregroundStyle(ForestPalette.ink)
                }
            }
        }
    }

    private func themeCardLink(_ theme: Theme, package: ContentPackage) -> some View {
        NavigationLink {
            CourseListView(themeId: theme.id)
        } label: {
            themeCard(theme, package: package)
        }
        .buttonStyle(.plain)
    }

    private func themeCard(_ theme: Theme, package: ContentPackage) -> some View {
        let accent = ForestPalette.themeAccent(themeId: theme.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: themeSymbol(theme.id))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 56, height: 56)
                    .background(ForestPalette.card.opacity(0.65), in: Circle())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(ForestPalette.card)
                    .frame(width: 36, height: 36)
                    .background(accent, in: Circle())
            }
            Text(theme.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(ForestPalette.ink)
            Text(theme.summary)
                .font(.body)
                .foregroundStyle(ForestPalette.inkSoft)
                .lineLimit(2)
            Text("\(package.courses(in: theme.id).count) 节课")
                .font(.callout.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(
            ForestPalette.themeCardBackground(themeId: theme.id),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: accent.opacity(0.22), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.title)，\(theme.summary)")
    }

    private func themeSymbol(_ themeId: String) -> String {
        switch themeId {
        case "theme_animals":
            return "pawprint.fill"
        case "theme_family":
            return "house.fill"
        case "theme_nature":
            return "mountain.2.fill"
        default:
            return "book.fill"
        }
    }


    @ViewBuilder
    private var cardsShortcut: some View {
        Group {
            if navMode == .homeCardsOnly {
                NavigationLink {
                    MyCardsView()
                } label: {
                    cardsShortcutLabel
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onSelectCardsTab) {
                    cardsShortcutLabel
                }
                .buttonStyle(.plain)
            }
        }
    }


    private var cardsShortcutLabel: some View {
        HStack {
            Image(systemName: "rectangle.on.rectangle.angled")
                .foregroundStyle(ForestPalette.leaf)
            Text("我的字卡")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var resultsBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的学习成果")
                .font(.title2.weight(.bold))
                .foregroundStyle(ForestPalette.ink)
            HStack(spacing: 12) {
                resultChip(symbol: "star.fill", color: ForestPalette.sun, title: "已获得星星", value: model.rewardCounts.stars)
                resultChip(symbol: "textformat", color: ForestPalette.leaf, title: "已学汉字", value: learnedHanziCount)
                resultChip(symbol: "checkmark.seal.fill", color: ForestPalette.sky, title: "本周完成", value: weeklyCompletedLessons, suffix: " 节课")
                Spacer(minLength: 0)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ForestPalette.mint)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }

    private func resultChip(symbol: String, color: Color, title: String, value: Int, suffix: String = "") -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ForestPalette.inkSoft)
                Text("\(value)\(suffix)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var learnedHanziCount: Int {
        model.learningRecords.filter { $0.masteryLevel != .notStarted }.count
    }

    private var weeklyCompletedLessons: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        return model.sessions.filter { session in
            session.sessionType == .newLearning
                && session.status == .completed
                && (session.completedAt ?? session.updatedAt) >= weekAgo
        }.count
    }
}
