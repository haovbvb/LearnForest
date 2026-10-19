import SwiftUI

/// 字卡详情。拼音跟着家长设置，发音只播包内文件。
struct HanziDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    let hanziId: String
    @State private var player = PronunciationPlayer()

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            if let hanzi = model.contentPackage?.hanzi(id: hanziId) {
                ScrollView {
                    detail(hanzi)
                }
            } else {
                Text("没有找到这个字。")
                    .font(.title2)
                    .foregroundStyle(ForestPalette.ink)
            }
        }
        .navigationTitle(model.contentPackage?.hanzi(id: hanziId)?.character ?? "字卡")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop(deactivateSession: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                player.stop(deactivateSession: true)
            }
        }
    }

    private func detail(_ hanzi: Hanzi) -> some View {
        let pinyin = PinyinStrategy.presentation(mode: model.activeProfile?.pinyinMode ?? .showWeak)
        let mastery = model.mastery(for: hanzi.id)
        return VStack(alignment: .leading, spacing: ForestSpacing.large) {
            Text(mastery.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ForestPalette.ink)
                .padding(.horizontal, ForestSpacing.medium)
                .frame(minHeight: 44)
                .background(ForestPalette.leaf.opacity(0.22), in: Capsule())
            HanziPicture(
                assetId: hanzi.imageAssetId,
                imageURL: model.bundledImageURL(hanzi.imageAssetId),
                minHeight: 220
            )
            Text(hanzi.character)
                .font(ForestType.lessonGlyph)
                .foregroundStyle(ForestPalette.ink)
                .frame(maxWidth: .infinity)
            if pinyin.showsPinyin {
                Text(hanzi.pinyin)
                    .font(.title)
                    .foregroundStyle(pinyin.isSecondary ? ForestPalette.inkSoft : ForestPalette.ink)
                    .frame(maxWidth: .infinity)
            } else {
                Text("拼音已按家长设置隐藏。")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
                    .frame(maxWidth: .infinity)
            }
            Text(hanzi.definition)
                .font(.title2)
                .foregroundStyle(ForestPalette.ink)
            Button {
                _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: true)
            } label: {
                Label(player.isPlaying ? "正在读" : "听一听", systemImage: "speaker.wave.2.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: ForestSpacing.minTouch)
            }
            .buttonStyle(.borderedProminent)
            .tint(ForestPalette.leaf)
            if let message = player.lastMessage {
                Text(message)
                    .font(.body)
                    .foregroundStyle(ForestPalette.ink)
            }
            if model.activeProfile?.quietMode == true {
                Text("安静模式开着。这里要点一下才会出声。")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            if let words = hanzi.wordExamples, !words.isEmpty {
                Text("可以组的词：\(words.joined(separator: "、"))")
                    .font(.title3)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            if mastery == .needsReview || ReviewQueue.pick(records: model.learningRecords).contains(hanzi.id) {
                Text("这个字可以在「去复习」里再看一看。答对之后，掌握会按原来的规则更新。")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            if model.contentPackage?.manifest.demoAssets == true {
                Text("图和声音还是演示占位，不是正式插画和普通话。")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .padding(ForestSpacing.screen)
        .frame(maxWidth: ForestSpacing.readingWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
