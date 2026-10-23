import SwiftUI

/// 间距、圆角和触控下限。儿童常用目标不小于 60×60 pt。
enum ForestSpacing {
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let screen: CGFloat = 32
    static let minTouch: CGFloat = 60
    static let heroMinHeight: CGFloat = 148
    static let cornerIcon: CGFloat = 64
    static let cardRadius: CGFloat = 28
    static let heroRadius: CGFloat = 36
    static let readingWidth: CGFloat = 720
}

enum ForestType {
    static let hero = Font.system(size: 40, weight: .bold, design: .rounded)
    static let glyph = Font.system(size: 88, weight: .medium, design: .rounded)
    static let lessonGlyph = Font.system(size: 120, weight: .medium, design: .rounded)
    static let glyphCompact = Font.system(size: 48, weight: .medium, design: .rounded)
    static let screenTitle = Font.largeTitle.weight(.bold)
}
