import SwiftUI

struct CourseListView: View {
    @Environment(AppModel.self) private var model
    let themeId: String

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let theme = model.contentPackage?.theme(id: themeId) {
                        Text(theme.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(ForestPalette.ink)
                    }
                    ForEach(courses) { course in
                        courseRow(course)
                    }
                }
                .padding(32)
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

    @ViewBuilder
    private func courseRow(_ course: Course) -> some View {
        let hanzi = model.contentPackage?.hanziList(for: course) ?? []
        let availability = CourseQualityGate.availability(
            course: course,
            hanziById: model.contentPackage?.hanziById ?? [:]
        )
        ForestCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(course.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                Text(course.description ?? "")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
                Text(statusLine(course: course, count: hanzi.count))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ForestPalette.leaf)
                if case .blocked(let reason) = availability {
                    Text(reason)
                        .font(.callout)
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                if !hanzi.isEmpty {
                    NavigationLink {
                        CharacterPreviewView(hanziIds: hanzi.map(\.id), courseTitle: course.title)
                    } label: {
                        Text("看看样例字")
                            .font(.body.weight(.semibold))
                            .frame(minHeight: 60)
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
        return "\(state) · \(count) 个样例字 · 难度 \(course.difficulty)"
    }
}
