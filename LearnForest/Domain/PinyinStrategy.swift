import Foundation

struct PinyinPresentation: Equatable {
    var showsPinyin: Bool
    /// 弱化时拼音让路给字形。
    var isSecondary: Bool
}

/// Sprint 2 的拼音策略只跟着家长设置走。声调配色和延迟出现还没做。
enum PinyinStrategy {
    static func presentation(mode: PinyinMode) -> PinyinPresentation {
        switch mode {
        case .hidden:
            PinyinPresentation(showsPinyin: false, isSecondary: true)
        case .showWeak:
            PinyinPresentation(showsPinyin: true, isSecondary: true)
        case .show:
            PinyinPresentation(showsPinyin: true, isSecondary: false)
        }
    }
}

enum PronunciationPolicy {
    /// 安静模式默认不自动读。只有家长打开「轻声自动读」才自动出声。
    static func allowsAutomaticPlay(quietMode: Bool, allowSoftAuto: Bool) -> Bool {
        if quietMode {
            return allowSoftAuto
        }
        return true
    }

    static func volume(quietMode: Bool, allowSoftAuto: Bool, userInitiated: Bool) -> Float {
        if !userInitiated && quietMode && allowSoftAuto {
            return 0.35
        }
        return 1
    }
}
