import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let profilesRepo: ChildProfileRepository
    private let learningRepo: LearningRepository
    let learningService: any LearningService

    var profiles: [ChildProfile] = []
    var activeProfile: ChildProfile?
    var contentPackage: ContentPackage?
    var contentError: String?
    var bootstrapError: String?
    var actionError: String?
    var rewardCounts = RewardCounts.zero
    var dailySnapshot = DailySnapshot.empty
    var hasInProgressSession = false
    var activeSession: LearningSession?
    var learningRecords: [LearningRecord] = []
    var installedContentVersion: Int?

    var primaryLearningTitle: String {
        hasInProgressSession ? "继续学习" : "今日学习"
    }

    var primaryLearningSubtitle: String {
        if hasInProgressSession, let title = continueCourseTitle {
            return "接着「\(title)」"
        }
        return "点这里开始"
    }

    var continueCourseTitle: String? {
        guard let courseId = activeSession?.courseId else { return nil }
        return contentPackage?.course(id: courseId)?.title
    }

    var progressCaption: String {
        let studied = dailySnapshot.studiedHanziIds.count
        let duration = DurationText.friendly(seconds: dailySnapshot.activeDurationSeconds)
        if studied == 0 && dailySnapshot.activeDurationSeconds == 0 {
            return "今天还没有学习记录 · 已学 \(duration)"
        }
        return "今天接触 \(studied) 个字 · 已学 \(duration)"
    }

    var themeLine: String {
        let titles = contentPackage?.themesSorted.map(\.title) ?? ["动物世界", "家庭生活", "自然世界"]
        return titles.joined(separator: " · ")
    }

    init(database: AppDatabase) {
        profilesRepo = ChildProfileRepository(queue: database.queue)
        learningRepo = LearningRepository(queue: database.queue)
        learningService = UnimplementedLearningService()
        loadContent()
        reload()
    }

    static func live() -> AppModel {
        do {
            return AppModel(database: try AppDatabase.onDisk())
        } catch {
            do {
                let model = AppModel(database: try AppDatabase.inMemory())
                model.bootstrapError = "本机数据库没有打开，这次先用临时内存库。学习记录不会留下。"
                return model
            } catch {
                fatalError("无法初始化本地数据库：\(error)")
            }
        }
    }

    static func preview() -> AppModel {
        do {
            return AppModel(database: try AppDatabase.inMemory())
        } catch {
            fatalError("预览数据库初始化失败：\(error)")
        }
    }

    func reload() {
        do {
            try profilesRepo.ensureDefaultProfile()
            profiles = try profilesRepo.list()
            activeProfile = try profilesRepo.active()
            guard let profileId = activeProfile?.id else { return }
            hasInProgressSession = try learningRepo.hasInProgressSession(profileId: profileId)
            activeSession = try learningRepo.inProgressSession(profileId: profileId)
            learningRecords = try learningRepo.records(profileId: profileId)
            rewardCounts = try learningRepo.rewardCounts(profileId: profileId)
            dailySnapshot = try learningRepo.dailySnapshot(profileId: profileId, now: Date())
        } catch {
            actionError = error.localizedDescription
        }
    }

    func createProfile(nickname: String) {
        let stage = activeProfile?.ageStage ?? .age3to4
        let learning = activeProfile?.learningStage ?? .enlightenment
        do {
            _ = try profilesRepo.create(nickname: nickname, ageStage: stage, learningStage: learning)
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func rename(id: String, nickname: String) {
        do {
            try profilesRepo.rename(id: id, nickname: nickname)
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func activate(id: String) {
        do {
            try profilesRepo.activate(id: id)
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func delete(id: String) {
        do {
            try profilesRepo.delete(id: id)
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func mastery(for hanziId: String) -> MasteryLevel {
        guard let record = learningRecords.first(where: { $0.hanziId == hanziId }) else {
            return .notStarted
        }
        return learningService.recordedMastery(of: record)
    }

    func showsPinyin(for profile: ChildProfile? = nil) -> Bool {
        (profile ?? activeProfile)?.pinyinMode != .hidden
    }

    func pinyinIsSecondary(for profile: ChildProfile? = nil) -> Bool {
        (profile ?? activeProfile)?.pinyinMode != .show
    }

    /// 打开本机占位预习。没有网络请求。资源不完整的课仍然不能当成正式课。
    func beginPlaceholderLesson() {
        guard let profileId = activeProfile?.id else { return }
        guard let courseId = placeholderCourseId() else {
            actionError = "这台 iPad 上还没有可以预习的汉字。"
            return
        }
        do {
            _ = try learningRepo.startOrResume(profileId: profileId, courseId: courseId, now: Date())
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func notePlaceholderIndex(_ index: Int) {
        guard let session = activeSession else { return }
        do {
            try learningRepo.updateIndex(sessionId: session.id, currentIndex: index, now: Date())
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func notePlaceholderStep(hanziId: String, index: Int) {
        guard let profileId = activeProfile?.id, let session = activeSession else { return }
        let existing = learningRecords.first { $0.hanziId == hanziId }?.masteryLevel
        let mastery = learningService.masteryAfterPlaceholderContact(existing: existing)
        do {
            try learningRepo.touchForPlaceholder(
                profileId: profileId,
                hanziId: hanziId,
                mastery: mastery,
                now: Date()
            )
            try learningRepo.updateIndex(sessionId: session.id, currentIndex: index, now: Date())
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func placeholderCourse() -> Course? {
        guard let package = contentPackage else { return nil }
        if let courseId = activeSession?.courseId, let course = package.course(id: courseId) {
            return course
        }
        return package.localPreviewCourses.first
    }

    private func placeholderCourseId() -> String? {
        if let courseId = activeSession?.courseId, contentPackage?.course(id: courseId) != nil {
            return courseId
        }
        return contentPackage?.localPreviewCourses.first?.id
    }

    func updateActive(_ body: (inout ChildProfile) -> Void) {
        guard var profile = activeProfile else { return }
        body(&profile)
        do {
            try profilesRepo.save(profile)
            reload()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func loadContent() {
        do {
            let package = try ContentPackageLoader.loadBundledPackage()
            contentPackage = package
            do {
                try learningRepo.noteContentInstall(package.manifest)
                installedContentVersion = try learningRepo.installedContentVersion(
                    packageId: package.manifest.contentPackageId
                )
            } catch {
                contentError = "课程包已读到，但版本记录没有写入：\(error.localizedDescription)"
            }
        } catch {
            contentError = error.localizedDescription
        }
    }
}
