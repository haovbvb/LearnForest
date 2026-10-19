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
    var sessions: [LearningSession] = []
    var learningRecords: [LearningRecord] = []
    var lessonCourseId: String?
    var lessonVisible = false
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
        learningService = ForestLearningService()
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
            sessions = try learningRepo.sessions(profileId: profileId)
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
        PinyinStrategy.presentation(mode: (profile ?? activeProfile)?.pinyinMode ?? .showWeak).showsPinyin
    }

    func pinyinIsSecondary(for profile: ChildProfile? = nil) -> Bool {
        PinyinStrategy.presentation(mode: (profile ?? activeProfile)?.pinyinMode ?? .showWeak).isSecondary
    }

    func hasBundledImage(_ assetId: String) -> Bool {
        LocalAssetLocator.hasImage(assetId: assetId)
    }

    func hasBundledAudio(_ assetId: String) -> Bool {
        LocalAssetLocator.hasAudio(assetId: assetId)
    }

    func bundledImageURL(_ assetId: String) -> URL? {
        LocalAssetLocator.imageURL(assetId: assetId)
    }

    func savedSession(courseId: String) -> LearningSession? {
        let matches = sessions.filter { $0.courseId == courseId }
        if let active = matches.first(where: { $0.status == .inProgress }) {
            return active
        }
        return matches.max { $0.updatedAt < $1.updatedAt }
    }

    /// 打开学习准备页。真正的会话要等孩子点「开始认字」才写。
    func presentLesson(courseId: String?) {
        guard let courseId, contentPackage?.course(id: courseId) != nil else {
            actionError = "这台 iPad 上还没有可以认的字。"
            return
        }
        lessonCourseId = courseId
        lessonVisible = true
    }

    func dismissLesson() {
        guard lessonVisible else { return }
        lessonVisible = false
        reload()
    }

    func beginCharacterLesson(courseId: String) {
        guard let profileId = activeProfile?.id else { return }
        do {
            let session = try learningRepo.beginCharacterLesson(profileId: profileId, courseId: courseId, now: Date())
            activeSession = session
            hasInProgressSession = true
            if let row = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[row] = session
            } else {
                sessions.insert(session, at: 0)
            }
            for index in sessions.indices where sessions[index].id != session.id && sessions[index].status == .inProgress {
                sessions[index].status = .interrupted
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    func rememberLessonIndex(_ index: Int) {
        guard let sessionId = activeSession?.id else { return }
        do {
            let now = Date()
            try learningRepo.updateIndex(sessionId: sessionId, currentIndex: index, now: now)
            activeSession?.currentIndex = index
            activeSession?.updatedAt = now
            if let row = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[row].currentIndex = index
                sessions[row].updatedAt = now
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    func noteCharacterContact(hanziId: String, index: Int) {
        guard let profileId = activeProfile?.id, activeSession != nil else { return }
        let existing = learningRecords.first { $0.hanziId == hanziId }?.masteryLevel
        let mastery = learningService.masteryAfterCharacterContact(existing: existing)
        let now = Date()
        do {
            try learningRepo.noteCharacterContact(
                profileId: profileId,
                hanziId: hanziId,
                mastery: mastery,
                now: now
            )
            rememberLessonIndex(index)
            if let row = learningRecords.firstIndex(where: { $0.hanziId == hanziId }) {
                learningRecords[row].masteryLevel = mastery
                learningRecords[row].lastPracticedAt = now
            } else {
                learningRecords.append(
                    LearningRecord.placeholderContact(
                        profileId: profileId,
                        hanziId: hanziId,
                        mastery: mastery,
                        now: now
                    )
                )
            }
            if !dailySnapshot.studiedHanziIds.contains(hanziId) {
                dailySnapshot.studiedHanziIds.append(hanziId)
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    func practiceQuestions(for courseId: String) -> [PracticeQuestion] {
        guard let package = contentPackage, let course = package.course(id: courseId) else { return [] }
        return ExerciseBuilder.questions(
            course: course,
            courseHanzi: package.hanziList(for: course),
            pool: package.hanzi
        )
    }

    func isFormalCourse(_ courseId: String) -> Bool {
        guard let course = contentPackage?.course(id: courseId) else { return false }
        if case .enterable = CourseQualityGate.availability(
            course: course,
            hanziById: contentPackage?.hanziById ?? [:],
            imageOnDisk: { self.hasBundledImage($0) },
            audioOnDisk: { self.hasBundledAudio($0) }
        ) {
            return true
        }
        return false
    }

    func rememberPracticeIndex(_ index: Int) {
        guard let sessionId = activeSession?.id else { return }
        do {
            let now = Date()
            try learningRepo.updatePracticeIndex(sessionId: sessionId, practiceIndex: index, now: now)
            activeSession?.practiceIndex = index
            activeSession?.updatedAt = now
            if let row = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[row].practiceIndex = index
                sessions[row].updatedAt = now
            }
        } catch {
            return
        }
    }

    func submitPracticeAnswer(
        questionId: String,
        questionSessionId: String,
        targetHanziId: String,
        selectedAnswer: String,
        isCorrect: Bool,
        attemptIndex: Int
    ) -> PracticeSubmitResult {
        guard let profileId = activeProfile?.id, let sessionId = activeSession?.id else {
            return .failed("还没有开始这节课。")
        }
        do {
            let save = try learningRepo.recordAnswer(
                profileId: profileId,
                sessionId: sessionId,
                questionId: questionId,
                questionSessionId: questionSessionId,
                targetHanziId: targetHanziId,
                selectedAnswer: selectedAnswer,
                isCorrect: isCorrect,
                attemptIndex: attemptIndex,
                now: Date()
            )
            switch save {
            case .duplicate:
                return .duplicate
            case .saved(let record):
                store(record)
                return .saved
            }
        } catch {
            return .failed("这次没记下，再点一次就好。")
        }
    }

    func finishPractice(courseId: String) -> PracticeReport? {
        guard let profileId = activeProfile?.id, let sessionId = activeSession?.id else { return nil }
        guard let course = contentPackage?.course(id: courseId) else { return nil }
        let hanzi = contentPackage?.hanziList(for: course) ?? []
        let names = Dictionary(uniqueKeysWithValues: hanzi.map { ($0.id, $0.character) })
        let questionCount = practiceQuestions(for: courseId).count
        do {
            let report = try learningRepo.finishPractice(
                profileId: profileId,
                sessionId: sessionId,
                courseId: courseId,
                hanziIds: hanzi.map(\.id),
                questionCount: questionCount,
                characterNames: names,
                now: Date()
            )
            reload()
            lessonVisible = true
            return report
        } catch {
            return nil
        }
    }

    private func store(_ record: LearningRecord) {
        if let row = learningRecords.firstIndex(where: { $0.hanziId == record.hanziId }) {
            learningRecords[row] = record
        } else {
            learningRecords.append(record)
        }
        if !dailySnapshot.studiedHanziIds.contains(record.hanziId) {
            dailySnapshot.studiedHanziIds.append(record.hanziId)
        }
    }

    /// 只记字卡和练习页处于前台的秒数，写到当前档案的当日时长和这节课的会话上。
    func recordStudyTime(seconds: Int) {
        guard seconds > 0, let profileId = activeProfile?.id, var session = activeSession else { return }
        do {
            try learningRepo.addStudyTime(
                profileId: profileId,
                sessionId: session.id,
                seconds: seconds,
                now: Date()
            )
            session.activeDurationSeconds += seconds
            activeSession = session
            dailySnapshot.activeDurationSeconds += seconds
            if let row = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[row].activeDurationSeconds += seconds
            }
        } catch {
            actionError = error.localizedDescription
        }
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
