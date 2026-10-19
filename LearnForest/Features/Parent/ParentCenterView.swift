import SwiftUI

/// 家长端：冷静的列表，不做复杂图表。云同步、内购、账号都不在这里实现。
struct ParentCenterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var showCreate = false
    @State private var newName = ""
    @State private var renaming: ChildProfile?
    @State private var renameText = ""
    @State private var pendingDelete: ChildProfile?

    var body: some View {
        Form {
            if let profile = model.activeProfile {
                Section("当前档案") {
                    LabeledContent("昵称", value: profile.displayName)
                    LabeledContent("阶段", value: profile.learningStage.title)
                    Text("切换、改名和删除都在这次家长验证里完成。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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
                            Button("删除", role: .destructive) {
                                pendingDelete = profile
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button("新建档案") {
                    newName = ""
                    showCreate = true
                }
            }
            todaySection
            settingsSection
            Section("关于与隐私") {
                Text(ProductIdentity.aboutLine)
                Text("英语线预留：\(ProductIdentity.reservedEnglishLine)。本包不会做成那条产品。")
                Text("学习记录、档案和奖励只在这台 iPad 上。V1.0 不登录、不同步、不内购。")
                LabeledContent("版本", value: appVersion)
                Text("TODO(Sprint 4)：隐私说明全文，以及按档案删除学习记录。删除记录不能删掉课程包。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("还没做") {
                Text("练习引擎、真实录音和插画、账号、内购、远程更新。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("家长中心")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .alert("新建档案", isPresented: $showCreate) {
            TextField("昵称", text: $newName)
            Button("创建") { model.createProfile(nickname: newName) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("新档案有自己的进度和奖励，不会带走现在这个孩子的记录。")
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
            DeleteProfileSheet(profile: profile) {
                model.delete(id: profile.id)
                pendingDelete = nil
            }
        }
    }

    private var todaySection: some View {
        Section("今日一览") {
            hanziLine("今日学了哪些字", ids: model.dailySnapshot.studiedHanziIds)
            hanziLine("哪些还不熟", ids: model.dailySnapshot.unfamiliarHanziIds)
            hanziLine("建议复习", ids: model.dailySnapshot.reviewSuggestionIds)
            LabeledContent(
                "今日已用时长",
                value: DurationText.friendly(seconds: model.dailySnapshot.activeDurationSeconds)
            )
            if let limit = model.activeProfile?.dailyDurationLimitMinutes {
                LabeledContent("每日上限", value: DurationText.limitLabel(limit))
            }
            Text("这里用短列表。复杂图表不放在第一屏。")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                Toggle("安静时仍自动轻声读", isOn: softPronounceBinding)
                    .disabled(!(model.activeProfile?.quietMode ?? false))
                Picker("儿童导航", selection: navBinding) {
                    ForEach(ChildNavMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text("改年龄或阶段不会清掉已学的字。到点温和结束、安静模式的声音策略还没接到学习流程。默认时长上限待确认。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func hanziLine(_ title: String, ids: [String]) -> some View {
        let names = ids.compactMap { model.contentPackage?.hanzi(id: $0)?.character }
        let value = names.isEmpty ? "还没有" : names.joined(separator: " ")
        return LabeledContent(title, value: value)
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
        binding(\.quietMode, default: false)
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

private struct MinuteChoice: Hashable, Identifiable {
    var minutes: Int?

    var id: String { minutes.map(String.init) ?? "off" }

    var title: String { minutes.map { "\($0) 分钟" } ?? "关闭" }

    static let session = [nil, 10, 15, 20].map { MinuteChoice(minutes: $0) }
    static let daily = [nil, 10, 15, 20, 30].map { MinuteChoice(minutes: $0) }
}

private struct DeleteProfileSheet: View {
    let profile: ChildProfile
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("会删掉「\(profile.displayName)」的学习记录、奖励和时长。没有云备份，删了找不回来。课程内容会留下。")
                    .font(.title3)
                Button(acknowledged ? "已了解" : "我已了解，继续") {
                    acknowledged = true
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 60)
                .disabled(acknowledged)
                Button("删除档案", role: .destructive, action: onDelete)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .disabled(!acknowledged)
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: 640, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("删除档案")
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
