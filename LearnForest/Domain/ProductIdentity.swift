import Foundation

/// 学习森林家族里的「识字森林」。
/// 英语线（英语森林 / Word Forest）只在此留名，不在本 App 实现。
enum ProductIdentity {
    static let familyName = "学习森林"
    static let familyNameEN = "LearnForest"
    static let appName = "识字森林"
    static let appNameEN = "Shizi Forest"
    static let reservedEnglishLine = "英语森林 / Word Forest"
    static let credit = "学习森林出品"
    static let productLineID = "shizi_forest"
    static let marketingVersion = "1.0.0"

    static var aboutLine: String {
        "\(credit)。本 App 是\(appName)（\(appNameEN)），工程模块名为 \(familyNameEN)。"
    }
}
