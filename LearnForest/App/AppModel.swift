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
    var installedContentVersion: Int?

    var primaryLearningTitle: String {
        hasInProgressSession ? "继续学习" : "今日学习"
    }

    var primaryLearningSubtitle: String {
        hasInProgressSession ? "接着上次的进度" : "点这里开始"
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
