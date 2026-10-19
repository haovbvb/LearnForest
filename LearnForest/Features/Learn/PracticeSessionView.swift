import SwiftUI

private enum PracticeFeedback: Equatable {
    case none
    case correct
    case again
    case problem(String)
}

/// 三种练习：听音找图、看字找图、点选配对。答错只轻轻提示，没有惩罚页。
struct PracticeSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    let courseId: String
    var tracksTime: Bool

    @State private var player = PronunciationPlayer()
    @State private var questionIndex = 0
    @State private var questionSessionIds: [String: String] = [:]
    @State private var attemptIndex = 1
    @State private var feedback: PracticeFeedback = .none
    @State private var advanceToken = 0
    @State private var pickedId: String?
    @State private var revealed = false
    @State private var wrongAttempts = 0
    @State private var selectedCharacterId: String?
    @State private var matchedIds: Set<String> = []
    @State private var report: PracticeReport?
    @State private var restReason: LessonRestReason?
    @State private var didRestore = false
    @State private var sittingSeconds = 0
    @State private var segmentStart: Date?

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            if let restReason {
                LessonRestView(
                    reason: restReason,
                    courseTitle: courseTitle,
                    seenCount: min(questionIndex + 1, max(questions.count, 1)),
                    totalCount: max(questions.count, 1)
                )
            } else if let report {
                PracticeResultView(courseTitle: courseTitle, report: report, demoAssets: demoAssets) {
                    restart()
                }
            } else if questions.isEmpty {
                missingQuestions
            } else if let question = currentQuestion {
                questionPage(question)
            } else {
                VStack(alignment: .leading, spacing: ForestSpacing.medium) {
                    Text(problemText)
                        .font(.title2)
                        .foregroundStyle(ForestPalette.ink)
                    Button("再记一次结果") { showReport() }
                        .font(.title3.weight(.semibold))
                        .frame(minHeight: ForestSpacing.minTouch)
                }
                .padding(ForestSpacing.screen)
            }
        }
        .navigationTitle(currentQuestion?.title ?? "练习")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: restoreIfNeeded)
        .onDisappear {
            player.stop(deactivateSession: true)
            pauseClock()
            guard didRestore, report == nil, restReason == nil else { return }
            model.rememberPracticeIndex(questionIndex)
        }
        .onChange(of: scenePhase) { _, phase in
            guard didRestore, report == nil, restReason == nil else { return }
            if phase != .active {
                player.stop(deactivateSession: true)
                pauseClock()
                model.rememberPracticeIndex(questionIndex)
            } else {
                resumeClock()
            }
        }
        .task(id: tracksTime && report == nil && restReason == nil) {
            guard tracksTime, report == nil, restReason == nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                tick()
            }
        }
        .task(id: advanceToken) {
            guard advanceToken > 0 else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            goNext()
        }
    }

    private func questionPage(_ question: PracticeQuestion) -> some View {
        VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("\(min(questionIndex + 1, questions.count)) / \(questions.count) · \(question.title)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.leaf)
            switch question {
            case .chooseImage(_, let prompt, let targetId, let choices):
                choosePage(prompt: prompt, targetId: targetId, choices: choices, question: question)
            case .matchPairs(_, let hanziIds, let imageOrder):
                matchPage(hanziIds: hanziIds, imageOrder: imageOrder, question: question)
            }
            feedbackLine
            Spacer(minLength: 0)
        }
        .padding(ForestSpacing.screen)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func choosePage(
        prompt: PracticePrompt,
        targetId: String,
        choices: [String],
        question: PracticeQuestion
    ) -> some View {
        if prompt == .listen {
            Text("听一听，点对应的图。")
                .font(.title2)
                .foregroundStyle(ForestPalette.ink)
            Button {
                if let hanzi = model.contentPackage?.hanzi(id: targetId) {
                    _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: true)
                }
            } label: {
                Label(player.isPlaying ? "正在读" : "听一听", systemImage: "speaker.wave.2.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
            }
            .buttonStyle(.borderedProminent)
            .tint(ForestPalette.leaf)
            if model.activeProfile?.quietMode == true && model.activeProfile?.quietModeAllowSoftAutoPronounce != true {
                Text("安静模式：点一下再听。")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        } else if let hanzi = model.contentPackage?.hanzi(id: targetId) {
            let pinyin = PinyinStrategy.presentation(mode: model.activeProfile?.pinyinMode ?? .showWeak)
            Text("看这个字，点对应的图。")
                .font(.title2)
                .foregroundStyle(ForestPalette.ink)
            Text(hanzi.character)
                .font(ForestType.lessonGlyph)
                .foregroundStyle(ForestPalette.ink)
                .frame(maxWidth: .infinity)
            if pinyin.showsPinyin {
                Text(hanzi.pinyin)
                    .font(.title2)
                    .foregroundStyle(pinyin.isSecondary ? ForestPalette.inkSoft : ForestPalette.ink)
                    .frame(maxWidth: .infinity)
            }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: ForestSpacing.medium)], spacing: ForestSpacing.medium) {
            ForEach(choices, id: \.self) { choiceId in
                choiceButton(choiceId: choiceId, targetId: targetId, question: question)
            }
        }
        if revealed {
            Button("下一题") { goNext() }
                .font(.title3.weight(.bold))
                .foregroundStyle(ForestPalette.ink)
                .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
        }
    }

    private func choiceButton(choiceId: String, targetId: String, question: PracticeQuestion) -> some View {
        let hanzi = model.contentPackage?.hanzi(id: choiceId)
        let isTarget = choiceId == targetId
        let showCorrect = revealed && isTarget
        let pickedWrong = pickedId == choiceId && choiceId != targetId && feedback == .again
        return Button {
            answerChoice(choiceId, targetId: targetId, question: question)
        } label: {
            HanziPicture(
                assetId: hanzi?.imageAssetId ?? choiceId,
                imageURL: model.bundledImageURL(hanzi?.imageAssetId ?? ""),
                minHeight: 160
            )
            .overlay {
                RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous)
                    .stroke(showCorrect ? ForestPalette.leaf : (pickedWrong ? ForestPalette.sun : Color.clear), lineWidth: 6)
            }
        }
        .buttonStyle(.plain)
        .disabled(feedback == .correct || revealed)
        .accessibilityLabel(showCorrect ? "这是要找的图" : "图片选项")
    }

    private func matchPage(hanziIds: [String], imageOrder: [String], question: PracticeQuestion) -> some View {
        VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("点一个字，再点它的图。")
                .font(.title2)
                .foregroundStyle(ForestPalette.ink)
            HStack(alignment: .top, spacing: ForestSpacing.large) {
                VStack(spacing: ForestSpacing.small) {
                    ForEach(hanziIds, id: \.self) { id in
                        let hanzi = model.contentPackage?.hanzi(id: id)
                        Button {
                            guard !matchedIds.contains(id) else { return }
                            selectedCharacterId = id
                        } label: {
                            Text(hanzi?.character ?? "")
                                .font(ForestType.glyphCompact)
                                .foregroundStyle(ForestPalette.ink)
                                .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                                .background(matchedIds.contains(id) ? ForestPalette.leaf.opacity(0.25) : ForestPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(selectedCharacterId == id ? ForestPalette.sun : Color.clear, lineWidth: 4)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(matchedIds.contains(id))
                    }
                }
                VStack(spacing: ForestSpacing.small) {
                    ForEach(imageOrder, id: \.self) { id in
                        let hanzi = model.contentPackage?.hanzi(id: id)
                        Button {
                            matchImage(id, question: question)
                        } label: {
                            HanziPicture(
                                assetId: hanzi?.imageAssetId ?? id,
                                imageURL: model.bundledImageURL(hanzi?.imageAssetId ?? ""),
                                minHeight: 96
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous)
                                    .stroke(matchedIds.contains(id) ? ForestPalette.leaf : Color.clear, lineWidth: 4)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(matchedIds.contains(id) || selectedCharacterId == nil)
                        .accessibilityLabel("图")
                    }
                }
            }
        }
    }

    private var feedbackLine: some View {
        Group {
            switch feedback {
            case .none:
                EmptyView()
            case .correct:
                Text(matchedIds.isEmpty ? "对了。" : "配好了。")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ForestPalette.leaf)
            case .again:
                Text(revealed ? "先记住这张图，下一题再试。" : "再看一看。")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ForestPalette.ink)
            case .problem(let message):
                Text(message)
                    .font(.title3)
                    .foregroundStyle(ForestPalette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, ForestSpacing.xSmall)
    }

    private var problemText: String {
        if case .problem(let message) = feedback {
            return message
        }
        return "结果还没写好，再记一次就好。"
    }

    private var missingQuestions: some View {
        Text("这节课还组不出练习。")
            .font(.title2)
            .foregroundStyle(ForestPalette.ink)
            .padding(ForestSpacing.screen)
    }

    private var questions: [PracticeQuestion] {
        model.practiceQuestions(for: courseId)
    }

    private var currentQuestion: PracticeQuestion? {
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    private var courseTitle: String {
        model.contentPackage?.course(id: courseId)?.title ?? "练习"
    }

    private var demoAssets: Bool {
        model.contentPackage?.manifest.demoAssets == true
    }

    private func restoreIfNeeded() {
        guard !didRestore else { return }
        model.beginCharacterLesson(courseId: courseId)
        let count = questions.count
        let saved = model.activeSession?.courseId == courseId ? (model.activeSession?.practiceIndex ?? 0) : 0
        questionIndex = count == 0 ? 0 : min(max(saved, 0), count)
        didRestore = true
        if count == 0 { return }
        if questionIndex >= count {
            showReport()
            return
        }
        if dailyLimitAlreadyReached {
            restReason = .dailyLimit
            return
        }
        resumeClock()
        autoplayCurrent()
    }

    private var dailyLimitAlreadyReached: Bool {
        StudyTimeLimit.reached(
            sittingSeconds: 0,
            sessionLimitMinutes: nil,
            dailySeconds: model.dailySnapshot.activeDurationSeconds,
            dailyLimitMinutes: model.activeProfile?.dailyDurationLimitMinutes
        ) == .daily
    }

    private func answerChoice(_ choiceId: String, targetId: String, question: PracticeQuestion) {
        guard feedback != .correct, !revealed else { return }
        let correct = choiceId == targetId
        switch commit(
            question: question,
            targetHanziId: targetId,
            selectedAnswer: choiceId,
            isCorrect: correct
        ) {
        case .duplicate:
            return
        case .failed(let message):
            feedback = .problem(message)
        case .saved:
            pickedId = choiceId
            if correct {
                feedback = .correct
                advanceToken += 1
            } else {
                wrongAttempts += 1
                feedback = .again
                if wrongAttempts >= 2 {
                    revealed = true
                }
            }
        }
    }

    private func matchImage(_ imageId: String, question: PracticeQuestion) {
        guard let selectedCharacterId, !matchedIds.contains(imageId), feedback != .correct else { return }
        let correct = selectedCharacterId == imageId
        switch commit(
            question: question,
            targetHanziId: selectedCharacterId,
            selectedAnswer: imageId,
            isCorrect: correct
        ) {
        case .duplicate:
            return
        case .failed(let message):
            feedback = .problem(message)
            self.selectedCharacterId = nil
        case .saved:
            if correct {
                matchedIds.insert(imageId)
                matchedIds.insert(selectedCharacterId)
                self.selectedCharacterId = nil
                if case .matchPairs(_, let ids, _) = question, matchedIds.isSuperset(of: ids) {
                    feedback = .correct
                    advanceToken += 1
                } else {
                    feedback = .none
                }
            } else {
                feedback = .again
                self.selectedCharacterId = nil
            }
        }
    }

    private func commit(
        question: PracticeQuestion,
        targetHanziId: String,
        selectedAnswer: String,
        isCorrect: Bool
    ) -> PracticeSubmitResult {
        let result = model.submitPracticeAnswer(
            questionId: question.id,
            questionSessionId: sessionId(for: question.id),
            targetHanziId: targetHanziId,
            selectedAnswer: selectedAnswer,
            isCorrect: isCorrect,
            attemptIndex: attemptIndex
        )
        if case .saved = result {
            attemptIndex += 1
        }
        return result
    }

    private func sessionId(for questionId: String) -> String {
        if let existing = questionSessionIds[questionId] {
            return existing
        }
        let created = UUID().uuidString
        questionSessionIds[questionId] = created
        return created
    }

    private func goNext() {
        guard report == nil else { return }
        let next = questionIndex + 1
        questionIndex = next
        model.rememberPracticeIndex(next)
        attemptIndex = 1
        wrongAttempts = 0
        revealed = false
        pickedId = nil
        feedback = .none
        matchedIds = []
        selectedCharacterId = nil
        player.stop(deactivateSession: false)
        if next >= questions.count {
            showReport()
        } else {
            autoplayCurrent()
        }
    }

    private func showReport() {
        player.stop(deactivateSession: true)
        pauseClock()
        if let finished = model.finishPractice(courseId: courseId) {
            report = finished
        } else {
            feedback = .problem("结果还没写好，再点一次下一题。")
        }
    }

    private func restart() {
        model.rememberPracticeIndex(0)
        questionIndex = 0
        questionSessionIds = [:]
        attemptIndex = 1
        wrongAttempts = 0
        revealed = false
        pickedId = nil
        feedback = .none
        matchedIds = []
        selectedCharacterId = nil
        report = nil
        advanceToken = 0
        resumeClock()
        autoplayCurrent()
    }

    private func autoplayCurrent() {
        guard tracksTime, restReason == nil, report == nil else { return }
        guard case .chooseImage(_, .listen, let targetId, _) = currentQuestion else { return }
        guard let hanzi = model.contentPackage?.hanzi(id: targetId) else { return }
        _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: false)
    }

    private func resumeClock() {
        guard tracksTime, restReason == nil, report == nil, segmentStart == nil, scenePhase == .active else { return }
        segmentStart = Date()
    }

    private func pauseClock() {
        guard let start = segmentStart else { return }
        let delta = max(0, Int(Date().timeIntervalSince(start)))
        segmentStart = nil
        if delta > 0 {
            sittingSeconds += delta
            model.recordStudyTime(seconds: delta)
        }
    }

    private func tick() {
        guard tracksTime, restReason == nil, report == nil, scenePhase == .active, let start = segmentStart else { return }
        let delta = max(0, Int(Date().timeIntervalSince(start)))
        guard delta > 0 else { return }
        segmentStart = Date()
        sittingSeconds += delta
        model.recordStudyTime(seconds: delta)
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

struct PracticeResultView: View {
    @Environment(AppModel.self) private var model
    let courseTitle: String
    let report: PracticeReport
    let demoAssets: Bool
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForestSpacing.large) {
                Text("这节课练完了")
                    .font(ForestType.screenTitle)
                    .foregroundStyle(ForestPalette.ink)
                Text(courseTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(ForestPalette.leaf)
                ForestCard {
                    VStack(alignment: .leading, spacing: ForestSpacing.small) {
                        Text("答对 \(report.correctAnswers) 次，一共点了 \(report.answerCount) 次。")
                            .font(.title3)
                            .foregroundStyle(ForestPalette.ink)
                        line("初步掌握", report.emergingCharacters)
                        line("稳定掌握", report.stableCharacters)
                        line("待复习", report.reviewCharacters)
                    }
                }
                ForestCard(background: ForestPalette.sun.opacity(0.35)) {
                    VStack(alignment: .leading, spacing: ForestSpacing.small) {
                        Text("这次新得到")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(ForestPalette.ink)
                        Text("星星 \(report.grant.stars) · 贴纸 \(report.grant.stickers) · 徽章 \(report.grant.badges)")
                            .font(.title3)
                            .foregroundStyle(ForestPalette.ink)
                        Text("同一种奖励不会发第二次。没有金币。")
                            .font(.body)
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                }
                if demoAssets {
                    Text("图和声音还是演示占位。掌握是按答题记的。")
                        .font(.body)
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Button(action: onRetry) {
                    Text("再学一次")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ForestPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                        .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    model.dismissLesson()
                } label: {
                    Text("回首页")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ForestPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: ForestSpacing.heroMinHeight * 0.7)
                        .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.heroRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(ForestSpacing.screen)
            .frame(maxWidth: ForestSpacing.readingWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func line(_ title: String, _ names: [String]) -> some View {
        Text("\(title)：\(names.isEmpty ? "还没有" : names.joined(separator: " "))")
            .font(.title3)
            .foregroundStyle(ForestPalette.ink)
    }
}
