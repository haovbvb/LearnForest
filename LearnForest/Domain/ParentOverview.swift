import Foundation

/// 家长学习总览用的纯计算。页面不读数据库，数字来自已经载入的当前档案。
enum ParentOverview {
    struct MasteryCounts: Equatable {
        var learning = 0
        var emerging = 0
        var stable = 0
        var needsReview = 0

        var summary: String {
            "学习中 \(learning) · 初步掌握 \(emerging) · 稳定掌握 \(stable) · 待复习 \(needsReview)"
        }

        var isEmpty: Bool {
            learning == 0 && emerging == 0 && stable == 0 && needsReview == 0
        }
    }

    struct CourseLine: Equatable, Identifiable {
        var id: String
        var title: String
        var detail: String
    }

    static func masteryCounts(_ records: [LearningRecord]) -> MasteryCounts {
        var counts = MasteryCounts()
        for record in records {
            switch record.masteryLevel {
            case .learning: counts.learning += 1
            case .emerging: counts.emerging += 1
            case .stable: counts.stable += 1
            case .needsReview: counts.needsReview += 1
            case .notStarted: break
            }
        }
        return counts
    }

    static func courseLines(
        package: ContentPackage,
        sessions: [LearningSession],
        records: [LearningRecord],
        questionCount: (String) -> Int
    ) -> [CourseLine] {
        package.themesSorted.flatMap { theme in
            package.courses(in: theme.id).map { course in
                line(theme: theme, course: course, package: package, sessions: sessions, records: records, questionCount: questionCount)
            }
        }
    }

    private static func line(
        theme: Theme,
        course: Course,
        package: ContentPackage,
        sessions: [LearningSession],
        records: [LearningRecord],
        questionCount: (String) -> Int
    ) -> CourseLine {
        let title = "\(theme.title) · \(course.title)"
        let hanzi = package.hanziList(for: course)
        if hanzi.isEmpty {
            return CourseLine(id: course.id, title: title, detail: "还没有汉字，不能开始正式学习。")
        }
        let counts = masteryCounts(records.filter { course.hanziIds.contains($0.hanziId) })
        let masteryText = counts.isEmpty ? nil : counts.summary
        guard let session = preferredSession(courseId: course.id, sessions: sessions) else {
            return CourseLine(id: course.id, title: title, detail: joined("还没开始。", masteryText))
        }
        let questions = questionCount(course.id)
        if questions > 0, session.practiceIndex >= questions {
            return CourseLine(id: course.id, title: title, detail: joined("练习已做完。", masteryText))
        }
        if session.practiceIndex > 0, questions > 0 {
            let shown = min(session.practiceIndex + 1, questions)
            return CourseLine(
                id: course.id,
                title: title,
                detail: joined("练习做到第 \(shown) / \(questions) 题。", masteryText)
            )
        }
        let index = min(max(session.currentIndex, 0), hanzi.count - 1)
        return CourseLine(
            id: course.id,
            title: title,
            detail: joined("认字看到第 \(index + 1) / \(hanzi.count) 个字。", masteryText)
        )
    }

    private static func preferredSession(courseId: String, sessions: [LearningSession]) -> LearningSession? {
        let matches = sessions.filter { $0.courseId == courseId }
        if let active = matches.first(where: { $0.status == .inProgress }) {
            return active
        }
        return matches.max { $0.updatedAt < $1.updatedAt }
    }

    private static func joined(_ lead: String, _ rest: String?) -> String {
        guard let rest else { return lead }
        return lead + rest
    }
}
