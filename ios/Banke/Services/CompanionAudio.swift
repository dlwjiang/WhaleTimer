import Foundation
import Combine
import AVFoundation

/// Two independent audio channels: mechanical feedback and cancellable character speech.
@MainActor
final class CompanionAudio: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    @Published private(set) var caption: String?
    @Published private(set) var captionCompanion: Companion?
    @Published private(set) var captionCue: String?
    @Published private(set) var captionID = 0
    @Published private(set) var speaking = false
    @Published private(set) var previewing = false
    var onInterruption: (() -> Void)?
    private var voicePlayer: AVAudioPlayer?
    private var effects: [AVAudioPlayer] = []
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?
    private var completion: CheckedContinuation<Bool, Never>?
    private var cueTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var generation = 0
    private var effectsGeneration = 0
    private var interruptionObserver: NSObjectProtocol?
    private var resetObserver: NSObjectProtocol?

    override init() {
        super.init()
        synthesizer.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main) { [weak self] notification in
                guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      type == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in
                    self?.stop(); self?.onInterruption?()
                    await CompanionAudioSession.shared.invalidate()
                }
            }
        resetObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stop(); self?.onInterruption?()
                    await CompanionAudioSession.shared.invalidate()
                }
            }
    }
    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let resetObserver { NotificationCenter.default.removeObserver(resetObserver) }
    }

    func effect(_ name: String, enabled: Bool) {
        guard enabled, let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio/Effects") else { return }
        let token = effectsGeneration
        Task { @MainActor [weak self] in
            guard let prepared = await CompanionAudioSession.shared.preparePlayer(at: url),
                  let self, self.effectsGeneration == token else { return }
            let player = prepared.player
            player.volume = 0.65
            self.effects.removeAll { !$0.isPlaying }; self.effects.append(player)
            player.play()
        }
    }

    func say(_ cue: String, companion: Companion, audible: Bool, preview: Bool = false, captionOverride: String? = nil) {
        stopSpeech()
        // Screen dismissal can happen before the queued playback task runs.
        previewing = preview
        cueTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            _ = await self.speak(cue, companion: companion, audible: audible, preview: preview, captionOverride: captionOverride)
        }
    }

    @discardableResult
    func speak(_ cue: String, companion: Companion, audible: Bool, preview: Bool = false, captionOverride: String? = nil) async -> Bool {
        guard !Task.isCancelled else { return false }
        cancelPlayback()
        clearTask?.cancel()
        generation += 1
        let token = generation
        caption = captionOverride ?? L10n.voice(cue, companion: companion)
        captionCompanion = companion
        captionCue = cue
        captionID += 1
        let captionStarted = Date()
        let briefCaption = Int(cue) != nil || cue == "go"
        let captionLifetime = briefCaption ? 0.95 : min(8, max(4.2, Double(caption?.count ?? 0) * 0.17))
        previewing = preview
        let result: Bool
        if audible {
            // Category/activation can block on the audio server; never perform them on the UI actor.
            let ready = await CompanionAudioSession.shared.activate()
            guard generation == token, !Task.isCancelled else { return false }
            let directory = "Audio/Voices/\(L10n.language.voiceDirectory)/\(companion.rawValue)"
            let prepared: PreparedCompanionPlayer?
            if ready, let url = Bundle.main.url(forResource: cue, withExtension: "m4a", subdirectory: directory) {
                prepared = await CompanionAudioSession.shared.preparePlayer(at: url)
            } else { prepared = nil }
            // Preparation may fail after cancellation. Do not fall through to
            // device speech for a cue that was stopped while the actor worked.
            guard generation == token, !Task.isCancelled else { return false }
            if !ready { result = await silentBeat(cue) }
            else if let prepared {
                let player = prepared.player
                voicePlayer = player
                player.delegate = self; player.volume = 0.8
                result = await withCheckedContinuation { continuation in
                    completion = continuation
                    speaking = player.play()
                    if speaking { armWatchdog(seconds: player.duration + 2, token: token) }
                    else { finish(false) }
                }
            } else if let voice = AVSpeechSynthesisVoice(language: L10n.language.speechLocale) {
                // Device speech is a fallback for a missing/damaged recording, never an English substitution.
                let utterance = AVSpeechUtterance(string: caption ?? "")
                utterance.voice = voice; utterance.rate = 0.48; utterance.volume = 0.8
                result = await withCheckedContinuation { continuation in
                    completion = continuation; speaking = true; activeUtterance = utterance
                    synthesizer.speak(utterance)
                    armWatchdog(seconds: 20, token: token)
                }
            } else { result = await silentBeat(cue) }
        } else { result = await silentBeat(cue) }
        guard generation == token else { return false }
        speaking = false
        clearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(0.18, captionLifetime - Date().timeIntervalSince(captionStarted))))
            guard !Task.isCancelled, self?.generation == token else { return }
            self?.caption = nil; self?.captionCompanion = nil; self?.captionCue = nil
            self?.previewing = false
        }
        return result && !Task.isCancelled
    }

    private func silentBeat(_ cue: String) async -> Bool {
        do { try await Task.sleep(for: .milliseconds(cue.count == 1 ? 750 : cue == "go" ? 600 : 1800)); return true }
        catch { return false }
    }

    func stopSpeech() {
        generation += 1; cueTask?.cancel(); cueTask = nil; clearTask?.cancel()
        cancelPlayback(); caption = nil; captionCompanion = nil; captionCue = nil; previewing = false
    }
    func stopEffects() { effectsGeneration += 1; effects.forEach { $0.stop() }; effects.removeAll() }
    func stop() { stopSpeech(); stopEffects() }
    private func cancelPlayback() {
        voicePlayer?.delegate = nil; voicePlayer?.stop(); voicePlayer = nil
        let hadUtterance = activeUtterance != nil
        activeUtterance = nil
        if hadUtterance { synthesizer.stopSpeaking(at: .immediate) }
        finish(false)
    }
    private func finish(_ success: Bool) {
        watchdog?.cancel(); watchdog = nil
        speaking = false
        let pending = completion; completion = nil
        pending?.resume(returning: success)
    }
    private func armWatchdog(seconds: Double, token: Int) {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self, self.generation == token else { return }
            self.cancelPlayback()
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.voicePlayer === player else { return }
            self?.voicePlayer = nil; self?.finish(flag)
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard self?.voicePlayer === player else { return }
            self?.voicePlayer = nil; self?.finish(false)
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in if self?.activeUtterance === utterance { self?.activeUtterance = nil; self?.finish(true) } }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in if self?.activeUtterance === utterance { self?.activeUtterance = nil; self?.finish(false) } }
    }
}

/// One serialized, non-UI executor owns the shared audio-session configuration.
/// Ambient playback respects the silent switch and mixes with the user's other audio.
private actor CompanionAudioSession {
    static let shared = CompanionAudioSession()
    private var ready = false

    func activate() -> Bool {
        if ready { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
            ready = true
            return true
        } catch { return false }
    }

    func invalidate() { ready = false }

    func preparePlayer(at url: URL) -> PreparedCompanionPlayer? {
        guard activate(), let player = try? AVAudioPlayer(contentsOf: url), player.prepareToPlay() else { return nil }
        return PreparedCompanionPlayer(player)
    }
}

/// Ownership transfers once from the preparation actor to the main actor.
/// The preparation actor never retains or accesses this player after returning it.
private struct PreparedCompanionPlayer: @unchecked Sendable {
    let player: AVAudioPlayer
    init(_ player: AVAudioPlayer) { self.player = player }
}
