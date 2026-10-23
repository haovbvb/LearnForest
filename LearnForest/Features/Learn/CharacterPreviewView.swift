import SwiftUI

/// 只展示字形。不写学习记录，也不把字标成掌握。
struct CharacterPreviewView: View {
    @Environment(AppModel.self) private var model
    let hanziIds: [String]
    let courseTitle: String

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(courseTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(ForestPalette.ink)
                    Text("样例预览。看一看不会记成学会。")
                        .font(.title3)
                        .foregroundStyle(ForestPalette.inkSoft)
                    ForEach(characters) { hanzi in
                        NavigationLink {
                            CharacterDetailPlaceholder(hanzi: hanzi)
                        } label: {
                            HanziCard(
                                character: hanzi.character,
                                pinyin: hanzi.pinyin,
                                showsPinyin: model.showsPinyin(),
                                pinyinIsSecondary: model.pinyinIsSecondary(),
                                definition: hanzi.definition,
                                statusTitle: model.mastery(for: hanzi.id).title,
                                compact: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(32)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("样例字")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var characters: [Hanzi] {
        hanziIds.compactMap { model.contentPackage?.hanzi(id: $0) }
    }
}

struct CharacterDetailPlaceholder: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    let hanzi: Hanzi
    @State private var player = PronunciationPlayer()

    var body: some View {
        ZStack {
            ForestPalette.cream.ignoresSafeArea()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 32) {
                    illustration
                    details
                }
                VStack(spacing: 24) {
                    illustration
                    details
                }
            }
            .padding(32)
            .frame(maxWidth: 980)
        }
        .navigationTitle(hanzi.character)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onDisappear { player.stop(deactivateSession: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                player.stop(deactivateSession: true)
            }
        }
    }

    private var illustration: some View {
        HanziPicture(assetId: hanzi.imageAssetId, imageURL: model.bundledImageURL(hanzi.imageAssetId))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(hanzi.character)
                .font(.system(size: 96, weight: .medium, design: .rounded))
                .foregroundStyle(ForestPalette.ink)
            if model.activeProfile?.pinyinMode != .hidden {
                Text(hanzi.pinyin)
                    .font(.title.weight(.medium))
                    .foregroundStyle(model.activeProfile?.pinyinMode == .showWeak ? ForestPalette.inkSoft : ForestPalette.ink)
            }
            Text(hanzi.definition)
                .font(.title2)
                .foregroundStyle(ForestPalette.ink)
            Button {
                _ = player.play(assetId: hanzi.audioAssetId, profile: model.activeProfile, userInitiated: true)
            } label: {
                Label(player.isPlaying ? "正在读" : "听一听", systemImage: "speaker.wave.2.fill")
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 160, minHeight: ForestSpacing.minTouch)
            }
            .buttonStyle(.borderedProminent)
            .tint(ForestPalette.leaf)
            if let audioMessage = player.lastMessage {
                Text(audioMessage)
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            if let words = hanzi.wordExamples, !words.isEmpty {
                Text("词语：\(words.joined(separator: "、"))")
                    .font(.body)
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
