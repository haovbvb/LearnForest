import Foundation

enum CourseAvailability: Equatable {
    case enterable
    case blocked(String)
}

/// 上架门槛见 PRD §7.4：图、标准音、字义、至少一种已实现的练习。
/// 骨架没有练习引擎，因此目前没有任何课程可进入。
enum CourseQualityGate {
    /// TODO(Sprint 3): 三种核心题型实现后，把对应 id 放进这个集合。
    static let implementedExerciseTypes: Set<String> = []

    static func availability(course: Course, hanziById: [String: Hanzi]) -> CourseAvailability {
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
