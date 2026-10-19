import Foundation

struct RemoteUpdateReservation: Codable, Equatable {
    var enabled: Bool
    var comment: String
}

struct ContentManifest: Codable, Equatable {
    var contentPackageId: String
    var contentVersion: Int
    var schemaVersion: Int
    var minimumAppVersion: String
    var assetsManifestVersion: Int
    var locale: String
    var title: String
    var productLine: String
    var themeIds: [String]
    var plannedCourseCount: Int
    var plannedHanziCount: Int
    var sampleHanziCount: Int
    var notes: String
    var remoteUpdate: RemoteUpdateReservation
}

struct Theme: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var coverAssetId: String
    var sortOrder: Int
    var contentVersion: Int
    var isAvailable: Bool
    var summary: String
}

struct Course: Codable, Equatable, Identifiable {
    var id: String
    var themeId: String
    var title: String
    var description: String?
    var stage: String
    var minRecommendedAge: Int
    var maxRecommendedAge: Int
    var difficulty: Int
    var learningObjectives: [String]
    var contentTypes: [String]
    var sortOrder: Int
    var contentVersion: Int
    /// published / placeholder / planned。只有 published 才可能进入学习。
    var status: String
    var hanziIds: [String]
    var exerciseTypes: [String]
}

struct Hanzi: Codable, Equatable, Identifiable {
    var id: String
    var character: String
    var pinyin: String
    var definition: String
    var audioAssetId: String
    var imageAssetId: String
    var difficulty: Int
    var tags: [String]
    var contentVersion: Int
    var isPublished: Bool
    var strokeCount: Int?
    var strokeDataId: String?
    var wordExamples: [String]?
    var sentenceExamples: [String]?
    var relatedHanziIds: [String]?
}

struct CourseHanziLink: Codable, Equatable {
    var courseId: String
    var hanziId: String
    var sortOrder: Int
    var isReview: Bool
}

struct ExerciseCatalogPlaceholder: Codable, Equatable {
    var implemented: Bool
    var todo: String
    var plannedTypes: [String]
    var notInV1: [String]
}

struct ContentPackage: Equatable {
    var manifest: ContentManifest
    var themes: [Theme]
    var courses: [Course]
    var hanzi: [Hanzi]
    var courseHanzi: [CourseHanziLink]
    var exercises: ExerciseCatalogPlaceholder

    var themesSorted: [Theme] {
        themes.sorted { $0.sortOrder < $1.sortOrder }
    }

    func courses(in themeId: String) -> [Course] {
        courses
            .filter { $0.themeId == themeId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func theme(id: String) -> Theme? {
        themes.first { $0.id == id }
    }

    func course(id: String) -> Course? {
        courses.first { $0.id == id }
    }

    var hanziById: [String: Hanzi] {
        Dictionary(uniqueKeysWithValues: hanzi.map { ($0.id, $0) })
    }

    func hanzi(id: String) -> Hanzi? {
        hanziById[id]
    }

    func hanziList(for course: Course) -> [Hanzi] {
        let map = hanziById
        return course.hanziIds.compactMap { map[$0] }
    }

    /// 本机已经有汉字正文的课，按主题和课序排列。没有网络也能列出来。
    var localPreviewCourses: [Course] {
        themesSorted.flatMap { theme in
            courses(in: theme.id).filter { !hanziList(for: $0).isEmpty }
        }
    }
}
