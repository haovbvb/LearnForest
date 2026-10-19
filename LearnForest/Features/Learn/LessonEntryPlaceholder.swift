import SwiftUI

/// 占位预习：打开本机课程包里的字，并按档案记住看到哪一张。
/// TODO(Sprint 2): 学习准备、标准发音、中断时长、到点温和结束。
/// TODO(Sprint 3): 听音找图、看字找图、汉字图片配对。资源不齐的课不能进这些练习。
struct LessonEntryPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @State private var index = 0
    @State private var audioMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ForestPalette.cream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: ForestSpacing.large) {
                    header
                    if characters.isEmpty {
                        ForestCard {
                            Text(model.contentError ?? "这台 iPad 上还没有可以预习的汉字。")
                                .font(.title3)
                                .foregroundStyle(ForestPalette.ink)
                        }
                        Spacer()
                    } else if let hanzi = current {
                        HanziCard(
                            character: hanzi.character,
                            pinyin: hanzi.pinyin,
                            showsPinyin: model.showsPinyin(),
                            pinyinIsSecondary: model.pinyinIsSecondary(),
                            definition: hanzi.definition,
                            statusTitle: model.mastery(for: hanzi.id).title
                        )
                        Button {
                            audioMessage = PronunciationPlayer.unavailableMessage(assetId: hanzi.audioAssetId)
                        } label: {
                            Label("听一听", systemImage: "speaker.wave.2.fill")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ForestPalette.leaf)
                        if let audioMessage {
                            Text(audioMessage)
                                .font(.body)
                                .foregroundStyle(ForestPalette.inkSoft)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: ForestSpacing.medium) {
                            Button("上一个") { goBack() }
                                .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
                                .disabled(index == 0)
                            Button(isLast ? "预习到这里" : "下一个") { goForward(from: hanzi) }
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: ForestSpacing.heroMinHeight * 0.55)
                                .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
                                .foregroundStyle(ForestPalette.ink)
                        }
                        .font(.title3.weight(.semibold))
                    }
                }
                .padding(ForestSpacing.screen)
                .frame(maxWidth: ForestSpacing.readingWidth)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear(perform: restore)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ForestSpacing.xSmall) {
            Text(course?.title ?? model.primaryLearningTitle)
                .font(ForestType.screenTitle)
                .foregroundStyle(ForestPalette.ink)
            Text("占位预习。练习还没做，不会记成掌握。")
                .font(.title3)
                .foregroundStyle(ForestPalette.inkSoft)
            if !characters.isEmpty {
                Text("\(index + 1) / \(characters.count) · \(model.activeProfile?.displayName ?? "小朋友")")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ForestPalette.leaf)
            }
        }
    }

    private var course: Course? {
        model.placeholderCourse()
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

    private func restore() {
        model.beginPlaceholderLesson()
        let count = characters.count
        let saved = model.activeSession?.currentIndex ?? 0
        index = count == 0 ? 0 : min(max(saved, 0), count - 1)
        audioMessage = nil
    }

    private func goBack() {
        guard index > 0 else { return }
        index -= 1
        audioMessage = nil
        model.notePlaceholderIndex(index)
    }

    private func goForward(from hanzi: Hanzi) {
        let next = min(index + 1, max(characters.count - 1, 0))
        model.notePlaceholderStep(hanziId: hanzi.id, index: next)
        index = next
        audioMessage = nil
    }
}
