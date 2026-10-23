import SwiftUI
import UIKit

/// 一节课里的汉字卡片。上一字、下一字都会把位置写进当前档案的会话。
struct CharacterCardLessonView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    let courseId: String
    var tracksTime: Bool

    @State private var player = PronunciationPlayer()
    @State private var index = 0
    @State private var sittingSeconds = 0
    @State private var segmentStart: Date?
    @State private var restReason: LessonRestReason?
    @State private var showPractice = false
    @State private var didRestore = false

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            if let restReason {
                LessonRestView(
                    reason: restReason,
                    courseTitle: course?.title ?? "认字",
                    seenCount: index + 1,
                    totalCount: max(characters.count, 1)
                )
            } else if characters.isEmpty {
                emptyState
            } else if let hanzi = current {
                cardPage(hanzi)
            }
        }
        .navigationTitle(course?.title ?? "认字")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: restoreIfNeeded)
        .onDisappear(perform: leaveCard)
        .onChange(of: scenePhase) { _, phase in
            guard restReason == nil else { return }
            if phase != .active {
                player.stop(deactivateSession: true)
                pauseClock()
                model.rememberLessonIndex(index)
            } else {
                resumeClock()
            }
        }
        .onChange(of: index) { _, newIndex in
            player.stop(deactivateSession: false)
            // 先让画面切过去，再写进度、再轻量自动读，避免主线程卡在 SQLite / 音频会话上。
            Task { @MainActor in
                model.rememberLessonIndex(newIndex)
                try? await Task.sleep(nanoseconds: 40_000_000)
                guard index == newIndex, restReason == nil, !showPractice else { return }
                autoplayIfAllowed()
            }
        }
        .navigationDestination(isPresented: $showPractice) {
            PracticeSessionView(courseId: courseId, tracksTime: tracksTime)
        }
        .onChange(of: showPractice) { _, isShowing in
            if isShowing {
                player.stop(deactivateSession: true)
                pauseClock()
            } else if restReason == nil {
                resumeClock()
            }
        }
        .task(id: tracksTime && restReason == nil && !showPractice) {
            guard tracksTime, restReason == nil, !showPractice else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                tick()
            }
        }
    }

    private func cardPage(_ hanzi: Hanzi) -> some View {
        let pinyin = PinyinStrategy.presentation(mode: model.activeProfile?.pinyinMode ?? .showWeak)
        return VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("\(index + 1) / \(characters.count) · \(model.activeProfile?.displayName ?? "小朋友")")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.leaf)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: ForestSpacing.large) {
                    HanziPicture(assetId: hanzi.imageAssetId, imageURL: model.bundledImageURL(hanzi.imageAssetId))
                    details(hanzi, pinyin: pinyin)
                }
                VStack(spacing: ForestSpacing.large) {
                    HanziPicture(assetId: hanzi.imageAssetId, imageURL: model.bundledImageURL(hanzi.imageAssetId))
                    details(hanzi, pinyin: pinyin)
                }
            }
            listenControl(hanzi)
            Spacer(minLength: 0)
            HStack(spacing: ForestSpacing.medium) {
                Button("上一个") { goBack() }
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                    .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
                    .foregroundStyle(ForestPalette.ink)
                    .disabled(index == 0)
                Button(forwardTitle) { goForward(from: hanzi) }
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.heroMinHeight * 0.55)
                    .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
                    .foregroundStyle(ForestPalette.ink)
            }
        }
        .padding(ForestSpacing.screen)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func details(_ hanzi: Hanzi, pinyin: PinyinPresentation) -> some View {
        VStack(alignment: pinyin.showsPinyin ? .leading : .center, spacing: ForestSpacing.small) {
            Text(hanzi.character)
                .font(ForestType.lessonGlyph)
                .foregroundStyle(ForestPalette.ink)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .center)
            if pinyin.showsPinyin {
                Text(hanzi.pinyin)
                    .font(pinyin.isSecondary ? .title2.weight(.medium) : .title.weight(.semibold))
                    .foregroundStyle(pinyin.isSecondary ? ForestPalette.inkSoft : ForestPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Text(hanzi.definition)
                .font(.title2)
                .foregroundStyle(ForestPalette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(model.mastery(for: hanzi.id).title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ForestPalette.ink)
                .padding(.horizontal, ForestSpacing.medium)
                .frame(minHeight: 36)
                .background(ForestPalette.leaf.opacity(0.22), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listenControl(_ hanzi: Hanzi) -> some View {
        VStack(alignment: .leading, spacing: ForestSpacing.xSmall) {
            Button {
                _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: true)
            } label: {
                Label(player.isPlaying ? "正在读" : "听一听", systemImage: "speaker.wave.2.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
            }
            .buttonStyle(.borderedProminent)
            .tint(ForestPalette.leaf)
            if model.activeProfile?.quietMode == true && model.activeProfile?.quietModeAllowSoftAutoPronounce != true {
                Text("安静模式：点一下再读。")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            if let lastMessage = player.lastMessage {
                Text(lastMessage)
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("这节课还没有汉字。")
                .font(.title)
                .foregroundStyle(ForestPalette.ink)
            Button("返回") { dismiss() }
                .frame(minHeight: ForestSpacing.minTouch)
        }
        .padding(ForestSpacing.screen)
    }

    private var course: Course? {
        model.contentPackage?.course(id: courseId)
    }

    private var characters: [Hanzi] {
        guard let course, let package = model.contentPackage else { return [] }
        return package.hanziList(for: course)
    }

    private var current: Hanzi? {
        guard characters.indices.contains(index) else { return nil }
        return characters[index]
    }

    private var isLast: Bool {
        !characters.isEmpty && index >= characters.count - 1
    }

    private var forwardTitle: String {
        if !isLast { return "下一个" }
        if tracksTime && model.isFormalCourse(courseId) { return "去做练习" }
        return "先到这里"
    }

    private func restoreIfNeeded() {
        guard !didRestore else { return }
        model.beginCharacterLesson(courseId: courseId)
        let count = characters.count
        let saved = model.activeSession?.courseId == courseId ? (model.activeSession?.currentIndex ?? 0) : 0
        index = count == 0 ? 0 : min(max(saved, 0), count - 1)
        didRestore = true
        model.rememberLessonIndex(index)
        if tracksTime && dailyLimitAlreadyReached {
            player.stop(deactivateSession: true)
            restReason = .dailyLimit
            return
        }
        resumeClock()
        autoplayIfAllowed()
    }

    private var dailyLimitAlreadyReached: Bool {
        StudyTimeLimit.reached(
            sittingSeconds: 0,
            sessionLimitMinutes: nil,
            dailySeconds: model.dailySnapshot.activeDurationSeconds,
            dailyLimitMinutes: model.activeProfile?.dailyDurationLimitMinutes
        ) == .daily
    }

    private func leaveCard() {
        player.stop(deactivateSession: true)
        pauseClock()
        guard didRestore else { return }
        model.rememberLessonIndex(index)
    }

    private func goBack() {
        guard index > 0 else { return }
        index -= 1
    }

    private func goForward(from hanzi: Hanzi) {
        let currentId = hanzi.id
        if isLast {
            player.stop(deactivateSession: true)
            pauseClock()
            // 最后一字先切状态，接触记录放到后台任务，按钮不堵。
            Task { @MainActor in
                model.noteCharacterContact(hanziId: currentId, index: index)
            }
            if tracksTime && model.isFormalCourse(courseId) {
                showPractice = true
            } else {
                restReason = .charactersSeen
            }
            return
        }
        let next = min(index + 1, max(characters.count - 1, 0))
        index = next
        Task { @MainActor in
            model.noteCharacterContact(hanziId: currentId, index: next)
        }
    }

    private func autoplayIfAllowed() {
        guard tracksTime, restReason == nil, let hanzi = current else { return }
        _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: false)
    }

    private func resumeClock() {
        guard tracksTime, restReason == nil, segmentStart == nil, scenePhase == .active else { return }
        segmentStart = Date()
    }

    private func pauseClock() {
        guard let start = segmentStart else { return }
        let delta = max(0, Int(Date().timeIntervalSince(start)))
        segmentStart = nil
        commit(delta)
    }

    private func tick() {
        guard tracksTime, restReason == nil, scenePhase == .active, let start = segmentStart else { return }
        let delta = max(0, Int(Date().timeIntervalSince(start)))
        // 满 3 秒再落库，减少切字时和写库撞车。
        guard delta >= 3 else { return }
        segmentStart = Date()
        commit(delta)
        evaluateLimit()
    }

    private func commit(_ delta: Int) {
        guard delta > 0 else { return }
        sittingSeconds += delta
        model.recordStudyTime(seconds: delta)
    }

    private func evaluateLimit() {
        guard tracksTime, restReason == nil else { return }
        guard let kind = StudyTimeLimit.reached(
            sittingSeconds: sittingSeconds,
            sessionLimitMinutes: model.activeProfile?.sessionDurationLimitMinutes,
            dailySeconds: model.dailySnapshot.activeDurationSeconds,
            dailyLimitMinutes: model.activeProfile?.dailyDurationLimitMinutes
        ) else { return }
        player.stop(deactivateSession: true)
        pauseClock()
        restReason = kind == .session ? .sessionLimit : .dailyLimit
    }
}

struct HanziPicture: View {
    let assetId: String
    let imageURL: URL?
    var minHeight: CGFloat = 280

    var body: some View {
        RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous)
            .fill(ForestPalette.sky.opacity(0.35))
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .overlay {
                if let image = HanziImageCache.image(assetId: assetId, url: imageURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(ForestSpacing.medium)
                } else {
                    VStack(spacing: ForestSpacing.small) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                        Text("插画占位")
                            .font(.title3.weight(.semibold))
                        Text("没有配图，不能开始正式学习。")
                            .font(.body)
                            .multilineTextAlignment(.center)
                        Text(assetId)
                            .font(.caption)
                    }
                    .foregroundStyle(ForestPalette.inkSoft)
                    .padding(ForestSpacing.medium)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(imageURL == nil ? "插画占位，没有配图，不能开始正式学习" : "汉字配图")
    }
}

/// 避免每次切字都同步读盘解码 PNG。
enum HanziImageCache {
    private static var store: [String: UIImage] = [:]

    static func image(assetId: String, url: URL?) -> UIImage? {
        if let cached = store[assetId] { return cached }
        guard let url, let image = UIImage(contentsOfFile: url.path) else { return nil }
        if store.count >= 48 { store.removeAll(keepingCapacity: true) }
        store[assetId] = image
        return image
    }
}
