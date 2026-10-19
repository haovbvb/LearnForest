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
