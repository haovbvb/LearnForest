import SwiftUI

/// 家长端：冷静的列表，首屏是今日一览，不放图表。云同步、内购、账号都不在这里。
struct ParentCenterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var showCreate = false
    @State private var newName = ""
    @State private var renaming: ChildProfile?
    @State private var renameText = ""
    @State private var pendingDelete: ChildProfile?
    @State private var pendingClear = false

    var body: some View {
        Form {
            todaySection
            overviewSection
            settingsSection
            profileSection
            privacySection
        }
        .navigationTitle("家长中心")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .onAppear { model.reload() }
        .alert("新建档案", isPresented: $showCreate) {
            TextField("昵称", text: $newName)
            Button("创建") { model.createProfile(nickname: newName) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("新档案有自己的进度、设置和奖励，不会带走现在这个孩子的记录。")
        }
        .alert("修改昵称", isPresented: renamePresented) {
            TextField("昵称", text: $renameText)
            Button("保存") {
                if let renaming {
                    model.rename(id: renaming.id, nickname: renameText)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $pendingDelete) { profile in
            ConfirmDataRemovalSheet(
                title: "删除档案",
                message: LocalDataScope.deleteProfile(named: profile.displayName),
                confirmTitle: "删除档案"
            ) {
                model.delete(id: profile.id)
                pendingDelete = nil
            }
        }
        .sheet(isPresented: $pendingClear) {
            ConfirmDataRemovalSheet(
                title: "清除学习数据",
                message: LocalDataScope.clearLearning(named: model.activeProfile?.displayName ?? "小朋友"),
                confirmTitle: "清除学习数据"
            ) {
                model.clearActiveLearningData()
                pendingClear = false
            }
        }
    }

    private var todaySection: some View {
        Section("今日一览") {
            Text("当前是「\(model.activeProfile?.displayName ?? "小朋友")」。换档案后，这里只看那一个孩子。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            hanziBlock("今日学了哪些字", ids: model.dailySnapshot.studiedHanziIds)
            hanziBlock("哪些还不熟或待复习", ids: model.dailySnapshot.unfamiliarHanziIds)
            hanziBlock("建议先复习", ids: model.dailySnapshot.reviewSuggestionIds)
            LabeledContent(
                "今日有效时长",
                value: DurationText.friendly(seconds: model.dailySnapshot.activeDurationSeconds)
            )
            if let limit = model.activeProfile?.dailyDurationLimitMinutes {
                LabeledContent("每日上限", value: DurationText.limitLabel(limit))
            }
            Text(rewardsTodayText)
                .font(.body)
            Text("字和掌握来自当前档案的学习记录，和练习结果页是同一份。今日新得到的星星、贴纸、徽章只算今天第一次领到的。有效时长只算字卡和练习页的前台时间。这里用短列表，不放图表。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        Section("学习总览") {
            Text(ParentOverview.masteryCounts(model.learningRecords).summary)
                .font(.body)
            Text("星星 \(model.rewardCounts.stars) · 贴纸 \(model.rewardCounts.stickers) · 徽章 \(model.rewardCounts.badges)")
                .font(.body)
            Text("这是当前档案累计的掌握和奖励。还没打开过的字不算在里面。没有金币。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let package = model.contentPackage {
                ForEach(courseLines(package)) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.title)
                            .font(.body.weight(.semibold))
                        Text(line.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text(model.contentError ?? "课程还没有准备好。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        if model.activeProfile != nil {
            Section("学习设置") {
                Picker("年龄", selection: ageBinding) {
                    ForEach(AgeStage.allCases) { stage in
                        Text(stage.title).tag(stage)
                    }
                }
                Picker("学习阶段", selection: learningBinding) {
                    ForEach(LearningStage.allCases) { stage in
                        Text(stage.title).tag(stage)
                    }
                }
                Picker("拼音", selection: pinyinBinding) {
                    ForEach(PinyinMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("单次时长上限", selection: sessionLimitBinding) {
                    ForEach(MinuteChoice.session) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Picker("每日时长上限", selection: dailyLimitBinding) {
                    ForEach(MinuteChoice.daily) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Toggle("安静模式", isOn: quietBinding)
                Toggle("安静时轻量自动发音", isOn: softPronounceBinding)
                    .disabled(!(model.activeProfile?.quietMode ?? false))
                Picker("儿童导航", selection: navBinding) {
                    ForEach(ChildNavMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text("这些写在当前档案里，关掉 App 再打开还在。换档案用那一份自己的设置。改年龄或阶段不会清掉已学的字。到点只温和结束。关掉安静模式时，轻量自动发音也会关掉。底栏和「仅首页大卡片」只会留一种。默认时长上限仍待确认，现在是关闭。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profileSection: some View {
        Section("档案") {
            ForEach(model.profiles) { profile in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(profile.displayName)
                            .font(.body.weight(.semibold))
                        if profile.isActive {
                            Text("当前")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    Text("\(profile.ageStage.title) · \(profile.learningStage.title)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        if !profile.isActive {
                            Button("切换") { model.activate(id: profile.id) }
                        }
                        Button("改名") {
                            renameText = profile.displayName
                            renaming = profile
                        }
                        if model.profiles.count > 1 {
                            Button("删除", role: .destructive) {
                                pendingDelete = profile
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Button("新建档案") {
                newName = ""
                showCreate = true
            }
            if model.profiles.count <= 1 {
                Text("这是最后一个档案，不能删除。要清掉学习记录，用下面的清除学习数据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacySection: some View {
        Section("隐私与数据") {
            Text(ProductIdentity.aboutLine)
            Text("英语线预留：\(ProductIdentity.reservedEnglishLine)。本包不会做成那条产品。")
            Text("存在这台 iPad 上的有：儿童档案和家长设置、认字与练习进度、答题、掌握、星星贴纸徽章、每日有效时长。没有账号，不上传，不同步，不内购。")
            Text("汉字、演示图和提示音在随 App 安装的课程包里。清除学习数据或删除档案都不会删掉课程包。")
            Text(LocalDataScope.sameScope)
            LabeledContent("版本", value: appVersion)
            Button("清除当前档案的学习数据", role: .destructive) {
                pendingClear = true
            }
            Text("账号、云同步、远程更新、描红和组词都不在这一版。真实插画和更多汉字还在准备。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var rewardsTodayText: String {
        let grant = model.dailySnapshot.rewardsToday
        if grant.stars == 0 && grant.stickers == 0 && grant.badges == 0 {
            return "今日还没有新的星星、贴纸或徽章。"
        }
        return "今日新得到：星星 \(grant.stars) · 贴纸 \(grant.stickers) · 徽章 \(grant.badges)"
    }

    private func courseLines(_ package: ContentPackage) -> [ParentOverview.CourseLine] {
        ParentOverview.courseLines(
            package: package,
            sessions: model.sessions,
            records: model.learningRecords,
            questionCount: { model.practiceQuestions(for: $0).count }
        )
    }

    private func hanziBlock(_ title: String, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(names(ids))
                .font(.body)
        }
        .padding(.vertical, 2)
    }

    private func names(_ ids: [String]) -> String {
        if ids.isEmpty { return "还没有" }
        return ids.map { id in
            let character = model.contentPackage?.hanzi(id: id)?.character ?? id
            return "\(character)（\(model.mastery(for: id).title)）"
        }.joined(separator: " ")
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var renamePresented: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var ageBinding: Binding<AgeStage> {
        binding(\.ageStage, default: .age3to4)
    }

    private var learningBinding: Binding<LearningStage> {
        binding(\.learningStage, default: .enlightenment)
    }

    private var pinyinBinding: Binding<PinyinMode> {
        binding(\.pinyinMode, default: .showWeak)
    }

    private var navBinding: Binding<ChildNavMode> {
        binding(\.childNavMode, default: .tabWithHero)
    }

    private var quietBinding: Binding<Bool> {
        Binding(
            get: { model.activeProfile?.quietMode ?? false },
            set: { newValue in
                model.updateActive { profile in
                    profile.quietMode = newValue
                    if !newValue {
                        profile.quietModeAllowSoftAutoPronounce = false
                    }
                }
            }
        )
    }

    private var softPronounceBinding: Binding<Bool> {
        binding(\.quietModeAllowSoftAutoPronounce, default: false)
    }

    private var sessionLimitBinding: Binding<MinuteChoice> {
        Binding(
            get: { MinuteChoice(minutes: model.activeProfile?.sessionDurationLimitMinutes) },
            set: { choice in
                model.updateActive { $0.sessionDurationLimitMinutes = choice.minutes }
            }
        )
    }

    private var dailyLimitBinding: Binding<MinuteChoice> {
        Binding(
            get: { MinuteChoice(minutes: model.activeProfile?.dailyDurationLimitMinutes) },
            set: { choice in
                model.updateActive { $0.dailyDurationLimitMinutes = choice.minutes }
            }
        )
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ChildProfile, T>, default fallback: T) -> Binding<T> {
        Binding(
            get: { model.activeProfile?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                model.updateActive { profile in
                    profile[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

private enum LocalDataScope {
    static let wiped = "学习记录、答题、学习进度、奖励和有效时长"
    static let kept = "课程包会留下。没有云备份，删了找不回来。"
    static let sameScope = "删除档案和清除学习数据，清掉的都是同一类：\(wiped)。"

    static func deleteProfile(named name: String) -> String {
        "会删掉「\(name)」的\(wiped)，档案本身也会删掉。\(kept)至少要留一个档案。"
    }

    static func clearLearning(named name: String) -> String {
        "会清掉「\(name)」的\(wiped)。档案、昵称和家长设置会留下。\(kept)"
    }
}

private struct MinuteChoice: Hashable, Identifiable {
    var minutes: Int?

    var id: String { minutes.map(String.init) ?? "off" }

    var title: String { minutes.map { "\($0) 分钟" } ?? "关闭" }

    static let session = [nil, 10, 15, 20].map { MinuteChoice(minutes: $0) }
    static let daily = [nil, 10, 15, 20, 30].map { MinuteChoice(minutes: $0) }
}

private struct ConfirmDataRemovalSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(message)
                    .font(.title3)
                Button(acknowledged ? "已了解" : "我已了解，继续") {
                    acknowledged = true
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 60)
                .disabled(acknowledged)
                Button(confirmTitle, role: .destructive, action: onConfirm)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .disabled(!acknowledged)
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: 640, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
