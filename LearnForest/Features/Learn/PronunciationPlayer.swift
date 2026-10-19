import AVFoundation
import Foundation
import Observation

/// 本地标准录音。没有文件就说明原因，不用在线语音合成。
/// 新的一声开始前会停掉上一声。退到后台、切字、离开字卡时由页面调用 stop。
@MainActor
@Observable
final class PronunciationPlayer {
    private let box = PlayerBox()
    private(set) var isPlaying = false
    private(set) var lastMessage: String?

    init() {
        box.onFinish = { [weak self] in
            self?.isPlaying = false
        }
        box.onInterrupted = { [weak self] in
            self?.stop(deactivateSession: false)
        }
    }

    func stop(deactivateSession: Bool = false) {
        box.stop()
        isPlaying = false
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    /// 自动播放被安静模式拦住时返回 nil，不提示错误。
    /// 孩子点了「听一听」但包里没有文件时，返回可以读出来的原因。
    @discardableResult
    func play(assetId: String, profile: ChildProfile?, userInitiated: Bool) -> String? {
        let quiet = profile?.quietMode ?? false
        let soft = profile?.quietModeAllowSoftAutoPronounce ?? false
        if !userInitiated && !PronunciationPolicy.allowsAutomaticPlay(quietMode: quiet, allowSoftAuto: soft) {
            return nil
        }
        stop(deactivateSession: false)
        guard let url = LocalAssetLocator.audioURL(assetId: assetId) else {
            guard userInitiated else { return nil }
            let message = "录音还没放进课程包（\(assetId)）。"
            lastMessage = message
            return message
        }
        let volume = PronunciationPolicy.volume(
            quietMode: quiet,
            allowSoftAuto: soft,
            userInitiated: userInitiated
        )
        switch box.start(url: url, volume: volume) {
        case .started:
            isPlaying = true
            lastMessage = nil
            return nil
        case .failed:
            let message = "这句录音打不开。"
            lastMessage = message
            return message
        }
    }
}

private final class PlayerBox: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    var onFinish: (() -> Void)?
    var onInterrupted: (() -> Void)?

    override init() {
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw),
                  type == .began else { return }
            self?.onInterrupted?()
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    enum Start {
        case started
        case failed
    }

    func start(url: URL, volume: Float) -> Start {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.volume = volume
            audio.delegate = self
            audio.prepareToPlay()
            guard audio.play() else { return .failed }
            player = audio
            return .started
        } catch {
            return .failed
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?()
        }
    }
}
