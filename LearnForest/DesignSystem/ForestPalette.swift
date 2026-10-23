import SwiftUI

/// 现代绘本：奶油底、森林绿品牌识别；主按钮与主题卡提高饱和度。
enum ForestPalette {
    static let cream = Color(red: 1.000, green: 0.973, blue: 0.925) // #FFF8EC
    static let leaf = Color(red: 0.263, green: 0.529, blue: 0.353) // #43875A
    static let sun = Color(red: 1.000, green: 0.784, blue: 0.239) // #FFC83D
    static let sky = Color(red: 0.451, green: 0.769, blue: 0.949) // #73C4F2
    static let mint = Color(red: 0.741, green: 0.910, blue: 0.784) // #BDE8C8
    static let coral = Color(red: 1.000, green: 0.573, blue: 0.471) // #FF9278
    static let ink = Color(red: 0.204, green: 0.184, blue: 0.161) // #342F29
    static let inkSoft = Color(red: 0.455, green: 0.400, blue: 0.341) // #746657
    static let card = Color.white
    static let parentBackground = Color(red: 0.953, green: 0.961, blue: 0.949) // #F3F5F2

    /// 动物主题卡暖黄（比 cream 更鲜）
    static let animalWarm = Color(red: 1.000, green: 0.910, blue: 0.620) // #FFE89E
    /// 家庭主题卡天蓝底
    static let familySoft = Color(red: 0.780, green: 0.910, blue: 0.980) // #C7E8FA

    /// 兼容旧调用；与 coral 同色。
    static let gentleAlert = coral

    static func themeCardBackground(themeId: String) -> Color {
        switch themeId {
        case "theme_animals":
            return animalWarm
        case "theme_family":
            return familySoft
        case "theme_nature":
            return mint
        default:
            return card
        }
    }

    static func themeAccent(themeId: String) -> Color {
        switch themeId {
        case "theme_animals":
            return sun
        case "theme_family":
            return sky
        case "theme_nature":
            return leaf
        default:
            return leaf
        }
    }
}
