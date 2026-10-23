import SwiftUI

struct CourseListView: View {
    @Environment(AppModel.self) private var model
    let themeId: String

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: ForestSpacing.medium) {
                    if let theme = model.contentPackage?.theme(id: themeId) {
                        Text(theme.title)
                            .font(ForestType.screenTitle)
                            .foregroundStyle(ForestPalette.ink)
                        Text(theme.summary)
                            .font(.title3)
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                    ForEach(courses) { course in
                        courseRow(course)
                    }
                }
                .padding(ForestSpacing.screen)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("课程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var courses: [Course] {
        model.contentPackage?.courses(in: themeId) ?? []
    }

    private func courseRow(_ course: Course) -> some View {
        let hanzi = model.contentPackage?.hanziList(for: course) ?? []
        let availability = CourseQualityGate.availability(
            course: course,
            hanziById: model.contentPackage?.hanziById ?? [:],
            imageOnDisk: { model.hasBundledImage($0) },
            audioOnDisk: { model.hasBundledAudio($0) }
        )
        let saved = model.savedSession(courseId: course.id)
        return ForestCard {
            VStack(alignment: .leading, spacing: ForestSpacing.small) {
                Button {
                    model.presentLesson(courseId: course.id)
                } label: {
                    VStack(alignment: .leading, spacing: ForestSpacing.small) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(course.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(ForestPalette.ink)
                            Spacer(minLength: ForestSpacing.small)
                            if model.activeSession?.courseId == course.id {
                                Text("继续")
                                    .font(.callout.weight(.bold))
                                    .foregroundStyle(ForestPalette.ink)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 32)
                                    .background(ForestPalette.sun, in: Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ForestPalette.inkSoft)
                        }
                        if let description = course.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(ForestPalette.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Text(statusLine(course: course, count: hanzi.count))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(ForestPalette.leaf)
                        if let saved, !hanzi.isEmpty {
                            let index = min(max(saved.currentIndex, 0), hanzi.count - 1)
                            Text("上次看到「\(hanzi[index].character)」")
                                .font(.callout)
                                .foregroundStyle(ForestPalette.ink)
                        }
                        if case .blocked(let reason) = availability {
                            Text(reason)
                                .font(.callout)
                                .foregroundStyle(ForestPalette.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Text(hanzi.isEmpty ? "先看准备页" : "进入学习准备")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(ForestPalette.leaf)
                            .frame(minHeight: ForestSpacing.minTouch, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if !hanzi.isEmpty {
                    NavigationLink {
                        CharacterPreviewView(hanziIds: hanzi.map(\.id), courseTitle: course.title)
                    } label: {
                        Text("只看样例，不记进度")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(ForestPalette.inkSoft)
                            .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch, alignment: .leading)
                    }
                }
            }
        }
    }

    private func statusLine(course: Course, count: Int) -> String {
        let state: String
        switch course.status {
        case "published": state = "已上架"
        case "placeholder": state = "样例"
        default: state = "计划中"
        }
        return "\(state) · \(count) 个字 · 难度 \(course.difficulty)"
    }
}
