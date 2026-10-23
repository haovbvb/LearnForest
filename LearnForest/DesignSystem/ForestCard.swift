import SwiftUI

struct ForestCard<Content: View>: View {
    var background: Color
    private let content: Content

    init(background: Color = ForestPalette.card, @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .padding(ForestSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: ForestSpacing.cardRadius, style: .continuous))
    }
}

struct CornerIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(ForestPalette.ink)
                .frame(width: ForestSpacing.cornerIcon, height: ForestSpacing.cornerIcon)
                .background(ForestPalette.card, in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
