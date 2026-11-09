import XCTest
import AVFoundation
import SwiftUI
@testable import Banke

@MainActor
final class ReleaseExperienceTests: XCTestCase {
    private var study: StudyStore!
    private var defaults: UserDefaults!
    private let suite = "BankeReleaseExperienceTests"

    override func setUp() async throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        study = StudyStore(purchases: PurchaseStore(), defaults: defaults)
        var settings = study.state.settings
        settings.soundEnabled = false
        study.updateSettings(settings)
    }
    override func tearDown() async throws {
        study.background()
        study = nil
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    func testOpeningWaitsForCuesThenResumeHasNoSecondCountdown() async throws {
        study.primaryAction()
        XCTAssertEqual(study.session.status, .preparing)
        XCTAssertNil(study.session.deadline)
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(study.session.remaining, 1500)
        try await Task.sleep(for: .milliseconds(3100))
        XCTAssertEqual(study.session.status, .running)
        study.primaryAction()
        let remaining = study.session.remaining
        XCTAssertEqual(study.session.status, .paused)
        study.primaryAction()
        XCTAssertEqual(study.session.status, .running)
        XCTAssertEqual(study.session.remaining, remaining)
    }

    func testResetAndBackgroundCancelPendingStart() async throws {
        study.primaryAction()
        try await Task.sleep(for: .milliseconds(100))
        study.reset()
        try await Task.sleep(for: .milliseconds(3200))
        XCTAssertEqual(study.session.status, .ready)
        XCTAssertNil(study.session.deadline)
        study.primaryAction()
        study.background()
        try await Task.sleep(for: .milliseconds(3200))
        XCTAssertEqual(study.session.status, .preparationPaused)
        XCTAssertNil(study.session.deadline)
        XCTAssertNil(study.audio.caption)
    }

    func testLanguageChangesAndCompanionsPreserveRunningDeadline() async throws {
        study.primaryAction()
        study.primaryAction() // Interrupt opening.
        study.primaryAction() // The unfinished opening must replay before timing starts.
        try await Task.sleep(for: .milliseconds(3400))
        let deadline = study.session.deadline
        XCTAssertNotNil(deadline)
        study.select(.pip)
        study.languageChanged()
        XCTAssertEqual(study.session.deadline, deadline)
        XCTAssertEqual(study.companion, .pip)
        study.reset()
        study.primaryAction()
        study.languageChanged()
        try await Task.sleep(for: .milliseconds(3200))
        XCTAssertEqual(study.session.status, .preparationPaused)
    }

    func testInterruptedOpeningReplaysLeadInWithoutSpendingFocusTime() async throws {
        study.primaryAction()
        try await Task.sleep(for: .milliseconds(900))
        study.primaryAction()
        XCTAssertEqual(study.session.status, .preparationPaused)
        XCTAssertEqual(study.session.remaining, 1500)
        study.primaryAction()
        XCTAssertEqual(study.session.status, .preparing)
        XCTAssertNil(study.session.deadline)
        try await Task.sleep(for: .milliseconds(3400))
        XCTAssertEqual(study.session.status, .running)
        XCTAssertNotNil(study.session.deadline)
    }

    func testSpeechCancelledBeforeTaskStartsCannotReappear() async throws {
        let audio = study.audio
        audio.say("greeting", companion: .mochi, audible: false)
        audio.stopSpeech()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(audio.caption)
        XCTAssertFalse(audio.speaking)
        audio.say("greeting", companion: .pip, audible: false)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(audio.captionCompanion, .pip)
        audio.say("pause", companion: .mochi, audible: false)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(audio.captionCompanion, .mochi)
        XCTAssertEqual(audio.caption, L10n.voice("pause", companion: .mochi))
        audio.stopSpeech()
    }

    func testRecordedPlaybackCompletesAndEffectsDoNotCancelSpeech() async throws {
        let audio = study.audio
        let directory = "Audio/Voices/\(L10n.language.voiceDirectory)/mochi"
        XCTAssertNotNil(Bundle.main.url(forResource: "greeting", withExtension: "m4a", subdirectory: directory))
        let greeting = Task { @MainActor in
            await audio.speak("greeting", companion: .mochi, audible: true)
        }
        for _ in 0..<50 {
            if audio.speaking { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(audio.speaking)
        audio.effect("play", enabled: true)
        try await Task.sleep(for: .milliseconds(50))
        audio.stopEffects()
        XCTAssertTrue(audio.speaking)
        let completed = await greeting.value
        XCTAssertTrue(completed)
        XCTAssertFalse(audio.speaking)

        let interrupted = Task { @MainActor in
            await audio.speak("greeting", companion: .pip, audible: true)
        }
        try await Task.sleep(for: .milliseconds(100))
        audio.stopSpeech()
        let cancelled = await interrupted.value
        XCTAssertFalse(cancelled)
        XCTAssertNil(audio.caption)
        XCTAssertFalse(audio.speaking)
    }

    func testEveryLanguageIsBundledAndDynamicFormatsResolve() throws {
        for language in AppLanguage.allCases {
            XCTAssertNotNil(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"), language.rawValue)
            let greeting = L10n.translate("voice.greeting.mochi", language: language)
            XCTAssertFalse(greeting.hasPrefix("voice."), language.rawValue)
            let minutes = L10n.translate("Focus: %lld min", language: language, args: [25])
            XCTAssertTrue(minutes.contains("25"), minutes)
            XCTAssertFalse(minutes.contains("%lld"), minutes)
            let title = L10n.translate("app.name", language: language)
            XCTAssertFalse(title.isEmpty)
            XCTAssertNotEqual(title, "app.name")
            let localizedBundle = try XCTUnwrap(Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)))
            XCTAssertEqual(localizedBundle.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist"), title)
            XCTAssertEqual(localizedBundle.localizedString(forKey: "CFBundleName", value: nil, table: "InfoPlist"), title)
            if language == .en { XCTAssertEqual(title, "Tick & Kin") }
            if language != .en {
                XCTAssertNotEqual(L10n.translate("Start focusing", language: language), "Start focusing", language.rawValue)
            }
        }
        for name in ["play", "pause", "bell"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio/Effects"))
        }
    }

    func testCompleteOfflineVoiceLibraryIsBundledAndFitsCountdownBeats() async throws {
        let cues = ["go", "pause", "resume", "reset", "focusComplete", "breakComplete", "1", "2", "3", "4", "5", "greeting"]
        let languages = Set(AppLanguage.allCases.map(\.voiceDirectory))
        var verified = 0
        for language in languages {
            for companion in Companion.allCases {
                for cue in cues {
                    let directory = "Audio/Voices/\(language)/\(companion.rawValue)"
                    let url = try XCTUnwrap(Bundle.main.url(forResource: cue, withExtension: "m4a", subdirectory: directory), "Missing \(directory)/\(cue)")
                    let duration = try await Task.detached(priority: .userInitiated) {
                        try AVAudioPlayer(contentsOf: url).duration
                    }.value
                    XCTAssertGreaterThan(duration, 0.1, url.path)
                    XCTAssertLessThan(duration, Int(cue) == nil ? 12 : 0.9, url.path)
                    verified += 1
                }
            }
        }
        XCTAssertEqual(verified, 768)
    }

    func testLiveTextSizeChangesThroughTimerCompletionPreserveSession() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let sizes = TextSizeProbe()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView:
            TextSizeProbeView(sizes: sizes)
                .environmentObject(study)
                .environmentObject(PurchaseStore())
                .environmentObject(study.audio))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKey() }
        study.primaryAction()
        try await Task.sleep(for: .milliseconds(3400))
        let deadline = try XCTUnwrap(study.session.deadline)
        for size in [DynamicTypeSize.xxxLarge, .accessibility1, .accessibility2,
                     .accessibility3, .accessibility4, .accessibility5, .large] {
            sizes.value = size
            try await Task.sleep(for: .milliseconds(120))
            XCTAssertEqual(study.session.deadline, deadline)
        }
        // Exercise the layout-axis change while final digits and completion update.
        study.tick(now: deadline.addingTimeInterval(-1))
        sizes.value = .accessibility5
        try await Task.sleep(for: .milliseconds(120))
        study.tick(now: deadline)
        sizes.value = .large
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(study.session.status, .complete)
        XCTAssertEqual(study.state.completedInCycle, 1)
        XCTAssertEqual(study.companion, .mochi)
    }
}

@MainActor
private final class TextSizeProbe: ObservableObject {
    @Published var value: DynamicTypeSize = .large
}

private struct TextSizeProbeView: View {
    @ObservedObject var sizes: TextSizeProbe
    var body: some View { StudyView().environment(\.dynamicTypeSize, sizes.value) }
}
