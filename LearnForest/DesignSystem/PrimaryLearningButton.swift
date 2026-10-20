import SwiftUI

/// 首页超大主按钮。触控区域远大于 60×60 pt，给 3～4 岁独立开课。
struct PrimaryLearningButton: View {
    let title: String
    var subtitle: String?
    var showsSunIcon: Bool = false
    var compactPill: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if showsSunIcon {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: compactPill ? 28 : 34, weight: .bold))
                        .foregroundStyle(ForestPalette.ink.opacity(0.85))
                        .accessibilityHidden(true)
                }
                VStack(alignment: showsSunIcon ? .leading : .center, spacing: 4) {
                    Text(title)
                        .font(compactPill ? .system(size: 28, weight: .bold, design: .rounded) : ForestType.hero)
                    if let subtitle {
                        Text(subtitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(ForestPalette.ink.opacity(0.72))
                    }
                }
                if compactPill {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ForestPalette.ink.opacity(0.55))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(ForestPalette.ink)
            .frame(maxWidth: compactPill ? nil : .infinity)
            .frame(minHeight: compactPill ? 72 : ForestSpacing.heroMinHeight)
            .padding(.horizontal, compactPill ? 28 : ForestSpacing.large)
            .padding(.vertical, compactPill ? 14 : ForestSpacing.small)
            .background(
                ForestPalette.sun,
                in: RoundedRectangle(cornerRadius: compactPill ? 40 : ForestSpacing.heroRadius, style: .continuous)
            )
            .shadow(color: ForestPalette.sun.opacity(0.45), radius: 12, y: 6)
        }
        .buttonStyle(ForestPressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "开始学习")
    }
}

struct ForestPressStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
