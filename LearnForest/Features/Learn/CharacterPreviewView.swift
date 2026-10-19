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
                            row(hanzi)
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

    private func row(_ hanzi: Hanzi) -> some View {
        ForestCard {
            HStack(spacing: 18) {
                Text(hanzi.character)
                    .font(.system(size: 56, weight: .medium, design: .rounded))
                    .foregroundStyle(ForestPalette.ink)
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 4) {
                    if model.activeProfile?.pinyinMode != .hidden {
                        Text(hanzi.pinyin)
                            .font(.title3)
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                    Text(hanzi.definition)
                        .font(.body)
                        .foregroundStyle(ForestPalette.ink)
                    Text(MasteryLevel.notStarted.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(ForestPalette.leaf)
                }
                Spacer()
            }
        }
    }
}

struct CharacterDetailPlaceholder: View {
    @Environment(AppModel.self) private var model
    let hanzi: Hanzi
    @State private var audioMessage: String?

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
    }

    private var illustration: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(ForestPalette.sky.opacity(0.35))
            .frame(maxWidth: .infinity, minHeight: 280)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("插画占位")
                        .font(.title3.weight(.semibold))
                    Text(hanzi.imageAssetId)
                        .font(.caption)
                }
                .foregroundStyle(ForestPalette.inkSoft)
            }
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
                audioMessage = PronunciationPlayer.unavailableMessage(assetId: hanzi.audioAssetId)
            } label: {
                Label("听一听", systemImage: "speaker.wave.2.fill")
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 160, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(ForestPalette.leaf)
            if let audioMessage {
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
