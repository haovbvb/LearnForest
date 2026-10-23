import SwiftUI

struct LearnView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: ForestSpacing.medium) {
                    Text("认字")
                        .font(ForestType.screenTitle)
                        .foregroundStyle(ForestPalette.ink)
                    Text("有演示图和声音的课可以认字并做练习。还没写进包里的课不能开始正式学习。")
                        .font(.title3)
                        .foregroundStyle(ForestPalette.inkSoft)
                    if let package = model.contentPackage {
                        ForEach(package.themesSorted) { theme in
                            NavigationLink {
                                CourseListView(themeId: theme.id)
                            } label: {
                                themeCard(theme, package: package)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("内容版本 \(model.installedContentVersion ?? package.manifest.contentVersion) · 计划 \(package.manifest.plannedCourseCount) 课、约 \(package.manifest.plannedHanziCount) 字")
                            .font(.callout)
                            .foregroundStyle(ForestPalette.inkSoft)
                    } else {
                        ForestCard {
                            Text(model.contentError ?? "课程还没有准备好。")
                                .foregroundStyle(ForestPalette.ink)
                        }
                    }
                }
                .padding(ForestSpacing.screen)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("认字")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func themeCard(_ theme: Theme, package: ContentPackage) -> some View {
        let count = package.courses(in: theme.id).count
        return ForestCard {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ForestPalette.themeCardBackground(themeId: theme.id))
                    .frame(width: 84, height: 84)
                    .overlay {
                        Image(systemName: theme.id == "theme_animals" ? "pawprint.fill" : (theme.id == "theme_family" ? "house.fill" : "mountain.2.fill"))
                            .font(.title2)
                            .foregroundStyle(ForestPalette.themeAccent(themeId: theme.id))
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(theme.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(ForestPalette.ink)
                    Text(theme.summary)
                        .font(.body)
                        .foregroundStyle(ForestPalette.inkSoft)
                    Text("\(count) 节 · 封面占位")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(ForestPalette.leaf)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
    }
}
