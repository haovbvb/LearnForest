import SwiftUI

/// 一小轮看字找图。字从待复习和错得比较多的记录里来，做完会更新掌握，不另发贴纸。
struct ReviewSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var player = PronunciationPlayer()
    @State private var questionIndex = 0
    @State private var questionSessionIds: [String: String] = [:]
    @State private var attemptIndex = 1
    @State private var feedback: ReviewFeedback = .none
    @State private var advanceToken = 0
    @State private var pickedId: String?
    @State private var revealed = false
    @State private var wrongAttempts = 0
    @State private var finished = false
    @State private var started = false
    @State private var savedCorrect = 0
    @State private var savedAnswers = 0
    @State private var didRestore = false
    @State private var restReason: LessonRestReason?
    @State private var sittingSeconds = 0
    @State private var segmentStart: Date?

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            if !didRestore {
                Text("在准备这一轮。")
                    .font(.title2)
                    .foregroundStyle(ForestPalette.inkSoft)
            } else if let restReason {
                LessonRestView(
                    reason: restReason,
                    courseTitle: "复习",
                    seenCount: min(questionIndex + 1, max(questions.count, 1)),
                    totalCount: max(questions.count, 1)
                )
            } else if !started {
                emptyReview
            } else if finished {
                ReviewResultView(correct: savedCorrect, total: savedAnswers, stillWaiting: stillWaiting) {
                    dismiss()
                }
            } else if let question = currentQuestion {
                questionPage(question)
            } else {
                emptyReview
            }
        }
        .navigationTitle("复习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: restoreIfNeeded)
        .onDisappear {
            player.stop(deactivateSession: true)
            pauseClock()
            if didRestore, started, !finished {
                model.rememberPracticeIndex(questionIndex)
            }
            model.unfocusReview()
        }
        .onChange(of: scenePhase) { _, phase in
            guard didRestore, started, !finished, restReason == nil else { return }
            if phase != .active {
                player.stop(deactivateSession: true)
                pauseClock()
                model.rememberPracticeIndex(questionIndex)
            } else {
                resumeClock()
            }
        }
        .task(id: started && !finished && restReason == nil) {
            guard started, !finished, restReason == nil else { return }
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

    private var emptyReview: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("现在没有要复习的字")
                .font(ForestType.screenTitle)
                .foregroundStyle(ForestPalette.ink)
            Text("等有字变成待复习，或者错得比答对还多，再来这里。多做练习就会出现。没有惩罚。")
                .font(.title3)
                .foregroundStyle(ForestPalette.ink)
            Button("回字卡") { dismiss() }
                .font(.title3.weight(.bold))
                .foregroundStyle(ForestPalette.ink)
                .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
        }
        .padding(ForestSpacing.screen)
        .frame(maxWidth: ForestSpacing.readingWidth, maxHeight: .infinity, alignment: .topLeading)
    }

    private func questionPage(_ question: PracticeQuestion) -> some View {
        let targetId = targetId(of: question)
        let choices = choices(of: question)
        return VStack(alignment: .leading, spacing: ForestSpacing.medium) {
            Text("\(min(questionIndex + 1, questions.count)) / \(questions.count) · 看字找图")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.leaf)
            if let hanzi = model.contentPackage?.hanzi(id: targetId) {
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
                Button {
                    _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: true)
                } label: {
                    Label(player.isPlaying ? "正在读" : "听一听", systemImage: "speaker.wave.2.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                }
                .buttonStyle(.borderedProminent)
                .tint(ForestPalette.leaf)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: ForestSpacing.medium)], spacing: ForestSpacing.medium) {
                ForEach(choices, id: \.self) { choiceId in
                    choiceButton(choiceId: choiceId, targetId: targetId, question: question)
                }
            }
            feedbackLine
            if revealed {
                Button("下一题") { goNext() }
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                    .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
            }
            Spacer(minLength: 0)
        }
        .padding(ForestSpacing.screen)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func choiceButton(choiceId: String, targetId: String, question: PracticeQuestion) -> some View {
        let hanzi = model.contentPackage?.hanzi(id: choiceId)
        let showCorrect = revealed && choiceId == targetId
        let pickedWrong = pickedId == choiceId && choiceId != targetId && feedback == .again
        return Button {
            answer(choiceId, targetId: targetId, question: question)
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

    private var feedbackLine: some View {
        Group {
            switch feedback {
            case .none:
                EmptyView()
            case .correct:
                Text("对了。")
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
    }

    private var questions: [PracticeQuestion] {
        guard let session = model.activeSession, session.sessionType == .review else { return [] }
        return ExerciseBuilder.reviewQuestions(
            targetIds: ReviewQueue.ids(in: session.reviewTargets),
            pool: model.contentPackage?.hanzi ?? []
        )
    }

    private var currentQuestion: PracticeQuestion? {
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    private var stillWaiting: [String] {
        ReviewQueue.pick(records: model.learningRecords, limit: 40).compactMap { id in
            model.contentPackage?.hanzi(id: id)?.character
        }
    }

    private func restoreIfNeeded() {
        guard !didRestore else { return }
        let opened = model.beginReview()
        let saved = model.activeSession?.sessionType == .review ? (model.activeSession?.practiceIndex ?? 0) : 0
        let count = questions.count
        questionIndex = count == 0 ? 0 : min(max(saved, 0), count)
        didRestore = true
        guard opened, count > 0 else { return }
        started = true
        if questionIndex >= count {
            complete()
            return
        }
        if StudyTimeLimit.reached(
            sittingSeconds: 0,
            sessionLimitMinutes: nil,
            dailySeconds: model.dailySnapshot.activeDurationSeconds,
            dailyLimitMinutes: model.activeProfile?.dailyDurationLimitMinutes
        ) == .daily {
            restReason = .dailyLimit
            return
        }
        resumeClock()
    }

    private func answer(_ choiceId: String, targetId: String, question: PracticeQuestion) {
        guard feedback != .correct, !revealed else { return }
        let correct = choiceId == targetId
        let result = model.submitPracticeAnswer(
            questionId: question.id,
            questionSessionId: sessionId(for: question.id),
            targetHanziId: targetId,
            selectedAnswer: choiceId,
            isCorrect: correct,
            attemptIndex: attemptIndex
        )
        switch result {
        case .duplicate:
            return
        case .failed(let message):
            feedback = .problem(message)
        case .saved:
            attemptIndex += 1
            savedAnswers += 1
            if correct { savedCorrect += 1 }
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

    private func sessionId(for questionId: String) -> String {
        if let existing = questionSessionIds[questionId] {
            return existing
        }
        let created = UUID().uuidString
        questionSessionIds[questionId] = created
        return created
    }

    private func goNext() {
        guard !finished else { return }
        let next = questionIndex + 1
        questionIndex = next
        model.rememberPracticeIndex(next)
        attemptIndex = 1
        wrongAttempts = 0
        revealed = false
        pickedId = nil
        feedback = .none
        player.stop(deactivateSession: false)
        if next >= questions.count {
            complete()
        }
    }

    private func complete() {
        player.stop(deactivateSession: true)
        pauseClock()
        model.finishReview(questionCount: questions.count)
        finished = true
    }

    private func targetId(of question: PracticeQuestion) -> String {
        if case .chooseImage(_, _, let target, _) = question { return target }
        return ""
    }

    private func choices(of question: PracticeQuestion) -> [String] {
        if case .chooseImage(_, _, _, let choices) = question { return choices }
        return []
    }

    private func resumeClock() {
        guard restReason == nil, !finished, segmentStart == nil, scenePhase == .active else { return }
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
        guard restReason == nil, !finished, scenePhase == .active, let start = segmentStart else { return }
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

private enum ReviewFeedback: Equatable {
    case none
    case correct
    case again
    case problem(String)
}

private struct ReviewResultView: View {
    let correct: Int
    let total: Int
    let stillWaiting: [String]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.large) {
            Text("这轮复习做完了")
                .font(ForestType.screenTitle)
                .foregroundStyle(ForestPalette.ink)
            Text(total == 0
                ? "这一轮已经做完。掌握按之前的答题留着。复习不另发贴纸。"
                : "这一轮记下 \(correct) 次答对，一共点了 \(total) 次。掌握已经按答题更新。复习不另发贴纸，也不会扣掉原来的星星。")
                .font(.title3)
                .foregroundStyle(ForestPalette.ink)
            Text(stillWaiting.isEmpty ? "现在没有还要复习的字。" : "还可以再看：\(stillWaiting.joined(separator: " "))")
                .font(.title3)
                .foregroundStyle(ForestPalette.ink)
            Button(action: onClose) {
                Text("回字卡")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                    .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(ForestSpacing.screen)
        .frame(maxWidth: ForestSpacing.readingWidth, maxHeight: .infinity, alignment: .topLeading)
    }
}
