import Foundation

/// TODO(Sprint 2): 用 AVFoundation 播放本地标准普通话。
/// 不要用在线语音合成来完成学习。快速连点时停掉上一声再播。
/// 安静模式默认改成手动播放；退到后台或退出课程时停播。
enum PronunciationPlayer {
    static func unavailableMessage(assetId: String) -> String {
        "录音还没放进课程包（\(assetId)）。"
    }
}
