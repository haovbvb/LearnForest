import Foundation

enum PracticePrompt: Equatable {
    /// 听声音，点对应的图。
    case listen
    /// 看汉字，点对应的图。
    case character
}

enum PracticeQuestion: Equatable, Identifiable {
    case chooseImage(id: String, prompt: PracticePrompt, targetHanziId: String, choiceHanziIds: [String])
    case matchPairs(id: String, hanziIds: [String], imageOrder: [String])

    var id: String {
        switch self {
        case .chooseImage(let id, _, _, _):
            id
        case .matchPairs(let id, _, _):
            id
        }
    }

    var title: String {
        switch self {
        case .chooseImage(_, .listen, _, _):
            "听音找图"
        case .chooseImage(_, .character, _, _):
            "看字找图"
        case .matchPairs:
            "汉字图片配对"
        }
    }
}

/// 用本课汉字组题。选项顺序按题目 id 固定，不靠系统随机，方便中断后还是同一题。
enum ExerciseBuilder {
    static func questions(course: Course, courseHanzi: [Hanzi], pool: [Hanzi]) -> [PracticeQuestion] {
        let targets = courseHanzi.filter { !$0.character.isEmpty && !$0.imageAssetId.isEmpty }
        guard !targets.isEmpty else { return [] }
        let allowed = Set(course.exerciseTypes).intersection(CourseQualityGate.implementedExerciseTypes)
        var questions: [PracticeQuestion] = []
        if allowed.contains(ExerciseType.listenAndSelectImage) {
            questions.append(contentsOf: chooseQuestions(courseId: course.id, prompt: .listen, targets: targets, pool: pool))
        }
        if allowed.contains(ExerciseType.characterToImage) {
            questions.append(contentsOf: chooseQuestions(courseId: course.id, prompt: .character, targets: targets, pool: pool))
        }
        if allowed.contains(ExerciseType.characterImageMatching) {
            let ids = targets.map(\.id)
            let images = seeded(ids, seed: "\(course.id)#images")
            questions.append(
                .matchPairs(
                    id: "\(course.id)#\(ExerciseType.characterImageMatching)",
                    hanziIds: ids,
                    imageOrder: images
                )
            )
        }
        return questions
    }

    /// 复习只用看字找图。目标顺序由调用方固定，避免做到一半题目列表变掉。
    static func reviewQuestions(targetIds: [String], pool: [Hanzi]) -> [PracticeQuestion] {
        let byId = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
        let targets = targetIds.compactMap { byId[$0] }.filter { !$0.character.isEmpty && !$0.imageAssetId.isEmpty }
        guard !targets.isEmpty else { return [] }
        return chooseQuestions(
            courseId: ReviewQueue.courseId,
            prompt: .character,
            targets: targets,
            pool: pool
        )
    }

    private static func chooseQuestions(
        courseId: String,
        prompt: PracticePrompt,
        targets: [Hanzi],
        pool: [Hanzi]
    ) -> [PracticeQuestion] {
        let type = prompt == .listen ? ExerciseType.listenAndSelectImage : ExerciseType.characterToImage
        return targets.map { target in
            let id = "\(courseId)#\(type)#\(target.id)"
            let others = pool.filter { $0.id != target.id && !$0.imageAssetId.isEmpty }
            let distractors = Array(seeded(others.map(\.id), seed: id).prefix(3))
            let choices = seeded([target.id] + distractors, seed: "\(id)#choices")
            return .chooseImage(id: id, prompt: prompt, targetHanziId: target.id, choiceHanziIds: choices)
        }
    }

    /// 稳定排序。不用 Hasher，避免每次启动顺序都变。
    static func seeded(_ ids: [String], seed: String) -> [String] {
        ids.sorted { lhs, rhs in
            let left = hash(seed + "#" + lhs)
            let right = hash(seed + "#" + rhs)
            if left == right { return lhs < rhs }
            return left < right
        }
    }

    private static func hash(_ text: String) -> UInt64 {
        var value: UInt64 = 14695981039346656037
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value &*= 1099511628211
        }
        return value
    }
}

/// 从待复习和错得比较多的字里挑一小轮。页面不自己改掌握。
enum ReviewQueue {
    static let courseId = "local_review"
    static let roundSize = 8

    static func ids(in targets: String) -> [String] {
        targets.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    static func joined(_ ids: [String]) -> String {
        ids.joined(separator: ",")
    }

    static func pick(records: [LearningRecord], limit: Int = roundSize) -> [String] {
        let ranked = records
            .filter { $0.masteryLevel == .needsReview || $0.incorrectCount > $0.correctCount }
            .sorted { lhs, rhs in
                let leftReview = lhs.masteryLevel == .needsReview
                let rightReview = rhs.masteryLevel == .needsReview
                if leftReview != rightReview { return leftReview }
                let leftGap = lhs.incorrectCount - lhs.correctCount
                let rightGap = rhs.incorrectCount - rhs.correctCount
                if leftGap != rightGap { return leftGap > rightGap }
                let leftDate = lhs.nextReviewAt ?? .distantFuture
                let rightDate = rhs.nextReviewAt ?? .distantFuture
                if leftDate != rightDate { return leftDate < rightDate }
                return lhs.hanziId < rhs.hanziId
            }
        return Array(ranked.prefix(limit)).map(\.hanziId)
    }
}
