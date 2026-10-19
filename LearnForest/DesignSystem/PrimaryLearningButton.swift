import SwiftUI

/// 首页超大主按钮。触控区域远大于 60×60 pt，给 3～4 岁独立开课。
struct PrimaryLearningButton: View {
    let title: String
    var subtitle: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(ForestPalette.ink.opacity(0.72))
                }
            }
            .foregroundStyle(ForestPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 148)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(ForestPalette.sun, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
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
