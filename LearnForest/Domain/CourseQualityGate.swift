import Foundation

enum CourseAvailability: Equatable {
    case enterable
    case blocked(String)
}

/// 上架门槛见 PRD §7.4：图、标准音、字义、至少一种已实现的练习。
/// 认字卡片可以打开本机文字。这里返回 blocked 的课不能当成正式学习。
enum CourseQualityGate {
    static let implementedExerciseTypes: Set<String> = [
        ExerciseType.listenAndSelectImage,
        ExerciseType.characterToImage,
        ExerciseType.characterImageMatching
    ]

    static func availability(
        course: Course,
        hanziById: [String: Hanzi],
        imageOnDisk: (String) -> Bool,
        audioOnDisk: (String) -> Bool
    ) -> CourseAvailability {
        guard course.status == "published" else {
            return .blocked("这节课还在准备，暂时不能学。")
        }
        guard !course.hanziIds.isEmpty else {
            return .blocked("这节课还没有汉字。")
        }
        for id in course.hanziIds {
            guard let hanzi = hanziById[id] else {
                return .blocked("缺少汉字内容。")
            }
            let missingMedia = hanzi.character.isEmpty
                || hanzi.definition.isEmpty
                || hanzi.audioAssetId.isEmpty
                || hanzi.imageAssetId.isEmpty
                || !hanzi.isPublished
                || !imageOnDisk(hanzi.imageAssetId)
                || !audioOnDisk(hanzi.audioAssetId)
            if missingMedia {
                return .blocked("还没到上架门槛：每个字都要有图、标准发音和字义。")
            }
        }
        guard !course.exerciseTypes.isEmpty else {
            return .blocked("这节课还没有练习。")
        }
        let pending = course.exerciseTypes.filter { !implementedExerciseTypes.contains($0) }
        if !pending.isEmpty {
            return .blocked("练习还在制作中。")
        }
        return .enterable
    }
}
