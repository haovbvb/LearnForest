import SwiftUI

/// 认字前的准备页。正式学习仍走上架门槛；缺图、缺录音或练习未做时不能从这里开始。
struct CoursePrepView: View {
    @Environment(AppModel.self) private var model
    let courseId: String

    @State private var showCards = false
    @State private var tracksTime = true

    var body: some View {
        NavigationStack {
            ZStack {
                ForestPalette.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: ForestSpacing.large) {
                        header
                        if let course {
                            progressCard(course)
                            formalStatus(course)
                            if characters.isEmpty {
                                ForestCard {
                                    Text("这节课还没有汉字，先不能认字。")
                                        .font(.title3)
                                        .foregroundStyle(ForestPalette.ink)
                                }
                            } else {
                                characterStrip
                                startControls
                            }
                        } else {
                            ForestCard {
                                Text(model.contentError ?? "没有找到这节课。")
                                    .font(.title3)
                                    .foregroundStyle(ForestPalette.ink)
                            }
                        }
                    }
                    .padding(ForestSpacing.screen)
                    .frame(maxWidth: ForestSpacing.readingWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("学习准备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { model.dismissLesson() }
                }
            }
            .navigationDestination(isPresented: $showCards) {
                CharacterCardLessonView(courseId: courseId, tracksTime: tracksTime)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.xSmall) {
            Text(course?.title ?? "课程")
                .font(ForestType.screenTitle)
                .foregroundStyle(ForestPalette.ink)
            if let themeTitle = themeTitle {
                Text(themeTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ForestPalette.leaf)
            }
            if let description = course?.description, !description.isEmpty {
                Text(description)
                    .font(.title3)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
    }

    private func progressCard(_ course: Course) -> some View {
        let saved = model.savedSession(courseId: course.id)
        return ForestCard {
            VStack(alignment: .leading, spacing: ForestSpacing.small) {
                Text(characters.isEmpty ? "还没有字" : "\(characters.count) 个字")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                if let saved, !characters.isEmpty {
                    let index = min(max(saved.currentIndex, 0), characters.count - 1)
                    Text("上次看到第 \(index + 1) 个字「\(characters[index].character)」")
                        .font(.title3)
                        .foregroundStyle(ForestPalette.ink)
                } else {
                    Text("还没开始。点下去会记住看到哪一个字。")
                        .font(.title3)
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Text(limitLine)
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
                if model.activeProfile?.quietMode == true {
                    Text(quietLine)
                        .font(.body)
                        .foregroundStyle(ForestPalette.inkSoft)
                }
            }
        }
    }

    private func formalStatus(_ course: Course) -> some View {
        ForestCard(background: ForestPalette.sky.opacity(0.28)) {
            VStack(alignment: .leading, spacing: ForestSpacing.small) {
                Text("正式学习")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                if let reason = formalBlockReason(course) {
                    Text(reason)
                        .font(.body)
                        .foregroundStyle(ForestPalette.ink)
                    Text("所以现在不能开始正式学习。")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ForestPalette.ink)
                } else {
                    Text("图、录音和练习都齐了，可以开始正式学习。")
                        .font(.body)
                        .foregroundStyle(ForestPalette.ink)
                }
                if picturesMissing {
                    Text("还有字没有配图。没有图的字卡上会标成占位，不能当成正式学习。")
                        .font(.body)
                        .foregroundStyle(ForestPalette.inkSoft)
                }
            }
        }
    }

    private var characterStrip: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.small) {
            Text("这节课的字")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.inkSoft)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: ForestSpacing.small)], spacing: ForestSpacing.small) {
                ForEach(characters) { hanzi in
                    Text(hanzi.character)
                        .font(ForestType.glyphCompact)
                        .foregroundStyle(ForestPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                        .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var startControls: some View {
        if dailyLimitReached {
            Text("今天的学习时间够了。可以先离开，想再看字也不会再计时，没有惩罚。")
                .font(.title3)
                .foregroundStyle(ForestPalette.ink)
            Button("再看一眼字") {
                tracksTime = false
                showCards = true
            }
            .buttonStyle(PrepButtonStyle())
        } else if formalReason == nil {
            PrimaryLearningButton(title: hasProgress ? "继续正式学习" : "开始正式学习", subtitle: "先认这节课的字") {
                tracksTime = true
                showCards = true
            }
        } else {
            PrimaryLearningButton(
                title: hasProgress ? "继续认字" : "开始认字",
                subtitle: "先认字。练习还没做，不会记成掌握"
            ) {
                tracksTime = true
                showCards = true
            }
            HStack(spacing: ForestSpacing.small) {
                Image(systemName: "lock.fill")
                Text("开始正式学习")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(ForestPalette.inkSoft)
            .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
            .background(ForestPalette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
            .accessibilityLabel("开始正式学习，现在不能点")
        }
    }

    private var course: Course? {
        model.contentPackage?.course(id: courseId)
    }

    private var themeTitle: String? {
        guard let themeId = course?.themeId else { return nil }
        return model.contentPackage?.theme(id: themeId)?.title
    }

    private var characters: [Hanzi] {
        guard let course, let package = model.contentPackage else { return [] }
        return package.hanziList(for: course)
    }

    private var hasProgress: Bool {
        model.savedSession(courseId: courseId) != nil
    }

    private var picturesMissing: Bool {
        characters.contains { !model.hasBundledImage($0.imageAssetId) }
    }

    private var dailyLimitReached: Bool {
        StudyTimeLimit.reached(
            sittingSeconds: 0,
            sessionLimitMinutes: nil,
            dailySeconds: model.dailySnapshot.activeDurationSeconds,
            dailyLimitMinutes: model.activeProfile?.dailyDurationLimitMinutes
        ) == .daily
    }

    private var limitLine: String {
        let today = DurationText.friendly(seconds: model.dailySnapshot.activeDurationSeconds)
        let session = DurationText.limitLabel(model.activeProfile?.sessionDurationLimitMinutes)
        let daily = DurationText.limitLabel(model.activeProfile?.dailyDurationLimitMinutes)
        return "今天已学 \(today) · 单次上限 \(session) · 每日上限 \(daily)"
    }

    private var quietLine: String {
        if model.activeProfile?.quietModeAllowSoftAutoPronounce == true {
            return "安静模式开着，进入字卡时会轻声自动读。"
        }
        return "安静模式开着，发音要自己点。"
    }

    private var formalReason: String? {
        guard let course else { return "没有找到这节课。" }
        return formalBlockReason(course)
    }

    private func formalBlockReason(_ course: Course) -> String? {
        let hanziById = model.contentPackage?.hanziById ?? [:]
        switch CourseQualityGate.availability(
            course: course,
            hanziById: hanziById,
            imageOnDisk: { model.hasBundledImage($0) },
            audioOnDisk: { model.hasBundledAudio($0) }
        ) {
        case .enterable:
            return nil
        case .blocked(let reason):
            return reason
        }
    }
}

private struct PrepButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(ForestPalette.ink)
            .frame(maxWidth: .infinity, minHeight: ForestSpacing.heroMinHeight * 0.7)
            .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.heroRadius, style: .continuous))
    }
}
