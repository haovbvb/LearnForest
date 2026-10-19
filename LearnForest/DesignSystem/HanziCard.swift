import SwiftUI

/// 基础字卡。字形是主角，拼音不抢位置。没有吉祥物。
struct HanziCard: View {
    var character: String
    var pinyin: String?
    var showsPinyin: Bool
    var pinyinIsSecondary: Bool
    var definition: String?
    var statusTitle: String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: ForestSpacing.small) {
            Text(character)
                .font(compact ? ForestType.glyphCompact : ForestType.glyph)
                .foregroundStyle(ForestPalette.ink)
                .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
                .minimumScaleFactor(0.6)
            if showsPinyin, let pinyin, !pinyin.isEmpty {
                Text(pinyin)
                    .font(compact ? .body : .title2)
                    .foregroundStyle(pinyinIsSecondary ? ForestPalette.inkSoft : ForestPalette.ink)
            }
            if let definition, !definition.isEmpty, !compact {
                Text(definition)
                    .font(.title3)
                    .foregroundStyle(ForestPalette.ink)
                    .multilineTextAlignment(.center)
            }
            Text(statusTitle)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ForestPalette.ink)
                .padding(.horizontal, ForestSpacing.medium)
                .frame(minHeight: 36)
                .background(ForestPalette.leaf.opacity(0.22), in: Capsule())
        }
        .padding(compact ? ForestSpacing.medium : ForestSpacing.large)
        .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
        .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
