import XCTest
import AVFoundation
import SwiftUI
import Combine
import StoreKitTest
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

    /// Await the state transition instead of assuming a busy simulator schedules
    /// every countdown task within 400 ms of its ideal three-second duration.
    private func waitForFocusStart() async throws {
        let timeout = ContinuousClock.now.advanced(by: .seconds(10))
        while study.session.status == .preparing, ContinuousClock.now < timeout {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(study.session.status, .running)
        XCTAssertNotNil(study.session.deadline)
    }

    func testIdlePollingDoesNotPublishUnchangedState() {
        var publications = 0
        let subscription = study.objectWillChange.sink { publications += 1 }
        defer { subscription.cancel() }
        for _ in 0..<100 { study.tick() }
        XCTAssertEqual(publications, 0, "Ready timer should not invalidate the entire scene")
        study.primaryAction()
        study.primaryAction()
        XCTAssertEqual(study.session.status, .preparationPaused)
        publications = 0
        for _ in 0..<100 { study.tick() }
        XCTAssertEqual(publications, 0, "Paused timer should not invalidate the entire scene")
    }

    func testClosingPreviewBeforePlaybackTaskStartsCancelsIt() async throws {
        study.previewVoice(.pip)
        study.stopVoicePreview()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(study.audio.caption)
        XCTAssertFalse(study.audio.previewing)
        XCTAssertFalse(study.audio.speaking)
    }

    func testClosingPreviewAfterPlaybackClearsLingeringCaption() async throws {
        _ = await study.audio.speak("greeting", companion: .pip, audible: false, preview: true)
        XCTAssertNotNil(study.audio.caption)
        study.stopVoicePreview()
        XCTAssertNil(study.audio.caption)
    }

    func testDisabledBreakCompletionKeepsFocusAndUsesNeutralCaption() async throws {
        var state = StudyState()
        state.settings.soundEnabled = false
        state.settings.shortBreaksEnabled = false
        state.settings.longBreaksEnabled = false
        state.session.start(at: Date())
        defaults.set(try JSONEncoder().encode(state), forKey: "banke.native.study.v1")
        study = StudyStore(purchases: PurchaseStore(), defaults: defaults)
        study.tick(now: try XCTUnwrap(study.session.deadline))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(study.session.status, .complete)
        XCTAssertEqual(study.state.nextPhase, .focus)
        XCTAssertEqual(study.audio.caption, L10n.text("Well done! Ready when you are."))
        study.primaryAction()
        XCTAssertEqual(study.session.phase, .focus)
        XCTAssertEqual(study.session.status, .preparing)
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
        try await waitForFocusStart()
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
        try await waitForFocusStart()
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
                XCTAssertNotEqual(L10n.translate("Cancel", language: language), "Cancel", language.rawValue)
            }
        }
        for name in ["play", "pause", "bell"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio/Effects"))
        }
    }

    func testEveryCompanionHasAllPosesAndLocalizedGreeting() throws {
        for companion in Companion.allCases {
            for pose in ["idle", "focus", "rest", "happy"] {
                let image = try XCTUnwrap(UIImage(named: "\(companion.rawValue)-\(pose)"))
                XCTAssertEqual(image.size.width, image.size.height)
                XCTAssertGreaterThan(image.size.width, 0)
            }
            for language in AppLanguage.allCases {
                let key = "voice.greeting.\(companion.rawValue)"
                let text = L10n.translate(key, language: language)
                XCTAssertFalse(text.isEmpty)
                XCTAssertNotEqual(text, key)
            }
        }
    }

    func testCompleteOfflineVoiceLibraryIsBundledAndFitsCountdownBeats() async throws {
        let cues = ["go", "pause", "resume", "reset", "focusComplete", "breakComplete", "1", "2", "3", "4", "5", "greeting", "poke"]
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
        XCTAssertEqual(verified, 1248)
    }

    /// Native review captures of all room themes, at explicit native view sizes, using local StoreKit transactions.
    func testDeviceRoomVisualReview() async throws {
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Companions", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        _ = try await session.buyProduct(identifier: CompanionPack.collectionProductID)
        let purchases = PurchaseStore()
        let entitlementDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            await purchases.refreshEntitlements()
            if purchases.availableCompanions == Companion.allCases { break }
            try await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < entitlementDeadline
        XCTAssertEqual(purchases.availableCompanions, Companion.allCases,
            "Local StoreKit did not deliver the review transaction")
        guard purchases.availableCompanions == Companion.allCases else { return }
        let suite = "BankeDeviceRoomReview"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let study = StudyStore(purchases: purchases, defaults: defaults)
        var settings = study.state.settings
        settings.soundEnabled = false
        study.updateSettings(settings)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let container = UIViewController()
        window.rootViewController = container
        window.makeKeyAndVisible()
        defer {
            study.background()
            window.isHidden = true
            previousWindow?.makeKey()
            if UIDevice.current.userInterfaceIdiom != .pad {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            defaults.removePersistentDomain(forName: suite)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DeviceRoomReview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "phone"
        let sizes: [(String, CGSize)] = device == "ipad"
            ? [("portrait", CGSize(width: 1024, height: 1366)), ("landscape", CGSize(width: 1366, height: 1024))]
            : [("portrait", CGSize(width: 393, height: 852)), ("landscape", CGSize(width: 852, height: 393))]
        for (name, requestedSize) in sizes {
            if device == "phone" {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: name == "portrait" ? .portrait : .landscapeRight)) {
                    XCTFail("Phone review rotation failed: \($0)")
                }
                try await Task.sleep(for: .seconds(1))
            }
            let size = device == "phone" ? window.bounds.size : requestedSize
            XCTAssertEqual(size.width > size.height, name == "landscape")
            let host = UIHostingController(rootView: StudyView()
                .environmentObject(study).environmentObject(study.audio).environmentObject(purchases))
            // iPad window mode can reject orientation changes. Render the same
            // production view at explicit portrait/landscape bounds without
            // inheriting the differently shaped parent window's safe area.
            if device == "ipad" { host.safeAreaRegions = [] }
            container.addChild(host)
            container.view.addSubview(host.view)
            host.view.frame = CGRect(origin: .zero, size: size)
            host.didMove(toParent: container)
            defer { host.willMove(toParent: nil); host.view.removeFromSuperview(); host.removeFromParent() }
            try await Task.sleep(for: .milliseconds(500))
            var captures: [UIImage] = []
            for companion in [Companion.mochi, .pip, .pebble, .jun, .luna, .nova] {
                study.select(companion)
                XCTAssertEqual(study.companion, companion)
                try await Task.sleep(for: .milliseconds(450))
                host.view.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                    host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
                }
                try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(device)-\(name)-\(companion.rawValue).png"))
                captures.append(image)
            }
            let cellWidth: CGFloat = name == "portrait" ? 300 : 500
            let cellHeight = cellWidth * size.height / size.width
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: cellWidth * 3, height: cellHeight * 2), format: format).image { _ in
                for (index, image) in captures.enumerated() {
                    image.draw(in: CGRect(x: CGFloat(index % 3) * cellWidth, y: CGFloat(index / 3) * cellHeight,
                                          width: cellWidth, height: cellHeight))
                }
            }
            try XCTUnwrap(sheet.pngData()).write(to: directory.appendingPathComponent("\(device)-\(name)-contact.png"))
        }
        print("Device room native captures: \(directory.path)")
    }

    func testShelfPurchasePreviewVisualReview() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfPreviewReview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var captures: [UIImage] = []
        for pack in CompanionPack.allCases {
            for poked in [false, true] {
                let renderer = ImageRenderer(content: CompanionShelfPreview(companions: pack.companions, poked: poked)
                    .frame(width: 600, height: 260))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size, CGSize(width: 600, height: 260))
                try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(pack.id)-\(poked ? "happy" : "idle").png"))
                captures.append(image)
            }
        }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 780), format: format).image { _ in
            for (index, image) in captures.enumerated() {
                image.draw(in: CGRect(x: CGFloat(index % 2) * 600, y: CGFloat(index / 2) * 260, width: 600, height: 260))
            }
        }
        try XCTUnwrap(sheet.pngData()).write(to: directory.appendingPathComponent("packs-contact.png"))
        print("Shelf preview native captures: \(directory.path)")
    }

    func testDeviceRoomsCoverEveryFormatWithoutGapsOrDistortion() throws {
        let windows: [(CGSize, Bool, DeviceRoomFormat)] = [
            (CGSize(width: 393, height: 852), false, .phone),
            (CGSize(width: 852, height: 393), false, .phoneLandscape),
            (CGSize(width: 1024, height: 1366), true, .padPortrait),
            (CGSize(width: 1366, height: 1024), true, .padLandscape),
            (CGSize(width: 375, height: 1024), true, .phone),
            (CGSize(width: 744, height: 1133), true, .padPortrait)]
        for (size, isPad, expected) in windows {
            let format = DeviceRoomFormat.resolve(size: size, isPad: isPad)
            XCTAssertEqual(format, expected)
            for room in DuoRoom.allCases {
                let image = try XCTUnwrap(UIImage(named: format.asset(room: room)))
                XCTAssertEqual(image.size.width / image.size.height, format.aspect, accuracy: 0.003)
                let ledgeY = size.height * (format.isLandscape ? 0.65 : 0.46)
                let frame = format.imageFrame(size: size, ledgeY: ledgeY, room: room,
                    characterX: size.width * (format.isLandscape ? 0.23 : 0.5))
                XCTAssertLessThanOrEqual(frame.minX, 0.01)
                XCTAssertLessThanOrEqual(frame.minY, 0.01)
                XCTAssertGreaterThanOrEqual(frame.maxX, size.width - 0.01)
                XCTAssertGreaterThan(frame.maxY, ledgeY) // The paper layer covers the remaining canvas.
                XCTAssertEqual(frame.width / frame.height, format.aspect, accuracy: 0.001)
                XCTAssertEqual(frame.minY + frame.height * room.perchFraction, ledgeY, accuracy: 0.001)
            }
        }
    }

    func testDeviceRoomCharactersKeepFeetOnFloorAcrossPoses() {
        for width in [320.0, 393.0, 600.0, 760.0] {
            for floor in [180.0, 340.0, 540.0] {
                for companion in Companion.allCases {
                    let frame = DeviceRoomSprite.frame(companion: companion, width: width, floorY: floor)
                    let union = DeviceRoomSprite.bounds(companion: companion, poked: false)
                        .union(DeviceRoomSprite.bounds(companion: companion, poked: true))
                    XCTAssertEqual(frame.minY + union.maxY * frame.height, floor, accuracy: 0.001)
                    for poked in [false, true] {
                        let bounds = DeviceRoomSprite.bounds(companion: companion, poked: poked)
                        XCTAssertGreaterThanOrEqual(frame.minY + bounds.minY * frame.height, 0)
                        XCTAssertGreaterThanOrEqual(frame.minX + bounds.minX * frame.width, 0)
                        XCTAssertLessThanOrEqual(frame.minX + bounds.maxX * frame.width, width)
                        XCTAssertLessThanOrEqual(frame.minY + bounds.maxY * frame.height, floor + 0.001)
                    }
                }
            }
        }
    }

    func testSharedPlatformArtworkKeepsBothExpressionsInsidePane() {
        for size in [CGSize(width: 320, height: 220), CGSize(width: 400, height: 400), CGSize(width: 600, height: 540)] {
            for companion in Companion.allCases {
                let frame = CompanionArtworkLayout.platform(calibrated: true)
                    .frame(companion: companion, width: size.width, height: size.height)
                for poked in [false, true] {
                    let bounds = DeviceRoomSprite.bounds(companion: companion, poked: poked)
                    XCTAssertGreaterThanOrEqual(frame.minX + bounds.minX * frame.width, 11.99)
                    XCTAssertGreaterThanOrEqual(frame.minY + bounds.minY * frame.height, 11.99)
                    XCTAssertLessThanOrEqual(frame.minX + bounds.maxX * frame.width, size.width - 11.99)
                    XCTAssertLessThanOrEqual(frame.minY + bounds.maxY * frame.height, size.height - 11.99)
                }
            }
        }
    }

    /// Capture the very same renderer with both expressions in every layout.
    /// Comparing rendered pixels catches missing or duplicated poke frames.
    func testSharedCompanionPokeArtworkAcrossDisplays() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SharedCompanionReview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let layouts: [(String, CGSize, CompanionArtworkLayout)] = [
            ("phone", CGSize(width: 361, height: 390), .perched(y: 280)),
            ("ipad", CGSize(width: 760, height: 600), .perched(y: 440)),
            ("duo", CGSize(width: 760, height: 620), .seated(hingeY: 480)),
            ("duo-landscape", CGSize(width: 400, height: 400), .platform(calibrated: true))]
        for companion in Companion.allCases {
            for (name, size, layout) in layouts {
                var images: [UIImage] = []
                for poked in [false, true] {
                    let renderer = ImageRenderer(content: CompanionArtwork(companions: [companion, companion, companion],
                        position: 0, width: size.width, height: size.height, layout: layout,
                        reduceMotion: true, poked: poked, speech: nil))
                    renderer.scale = 1
                    images.append(try XCTUnwrap(renderer.uiImage))
                }
                XCTAssertNotEqual(images[0].pngData(), images[1].pngData(), "Missing poke expression: \(companion) / \(name)")
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let sheet = UIGraphicsImageRenderer(size: CGSize(width: size.width * 2, height: size.height), format: format).image { _ in
                    for (index, image) in images.enumerated() {
                        image.draw(in: CGRect(x: CGFloat(index) * size.width, y: 0, width: size.width, height: size.height))
                    }
                }
                try XCTUnwrap(sheet.pngData()).write(to: directory.appendingPathComponent("\(companion.rawValue)-\(name).png"))
            }
        }
        print("Shared companion review: \(directory.path)")
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
        try await waitForFocusStart()
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

    func testTabletopTimerFitsItsPaneAtStandardTextSize() {
        for size in [CGSize(width: 760, height: 860), CGSize(width: 760, height: 1000),
                     CGSize(width: 900, height: 1100)] {
            for companion in Companion.free {
                let division = CGRect(x: 0, y: size.height * 0.47, width: size.width, height: 16)
                let layout = TabletopSceneLayout(size: size, division: division, companion: companion)
                let host = UIHostingController(rootView:
                    TimerPanel(compact: true, clockHeight: layout.clockHeight(width: size.width))
                        .fixedSize(horizontal: false, vertical: true)
                        .environment(\.dynamicTypeSize, .large)
                        .environmentObject(study))
                let measured = host.sizeThatFits(in: CGSize(width: min(900, size.width - 40), height: 2000))
                XCTAssertLessThanOrEqual(measured.height + 24, layout.timerHeight,
                    "\(companion): \(size) must show the complete card without scrolling or cropping")
            }
        }
    }

    func testHingeCountdownWordsStayOnOneCompactLineInEveryLanguage() {
        for language in AppLanguage.allCases {
            for cue in ["1", "2", "3", "4", "5", "go"] {
                let speech = CompanionSpeech(id: 1, text: L10n.translate("voice.\(cue)", language: language),
                                             cue: cue, speaker: .jun)
                let host = UIHostingController(rootView:
                    FloatingSpeechText(speech: speech, color: .brown, compact: true)
                        .environment(\.dynamicTypeSize, .large))
                let wide = host.sizeThatFits(in: CGSize(width: 600, height: 1000))
                for width in [96.0, 146.0, 224.0] {
                    let narrow = host.sizeThatFits(in: CGSize(width: width, height: 1000))
                    XCTAssertLessThanOrEqual(narrow.width, width + 1, "\(language): \(cue)")
                    XCTAssertLessThanOrEqual(narrow.height, wide.height + 1, "\(language): \(cue) must not wrap")
                    XCTAssertLessThan(narrow.height, 55, "Countdown should use compact typography")
                }
            }
        }
    }

    func testHingeSpeechStillRespectsAccessibilityTextSize() {
        let speech = CompanionSpeech(id: 1, text: "Take a breath. I'll wait.", cue: "pause", speaker: .jun)
        func measured(_ size: DynamicTypeSize) -> CGSize {
            UIHostingController(rootView:
                FloatingSpeechText(speech: speech, color: .brown, compact: true)
                    .environment(\.dynamicTypeSize, size))
                .sizeThatFits(in: CGSize(width: 224, height: 2000))
        }
        XCTAssertGreaterThan(measured(.accessibility3).height, measured(.large).height)
    }

    func testPokeUsesItsOwnLocalizedResponseWithoutChangingFocusDeadline() async throws {
        study.primaryAction()
        try await waitForFocusStart()
        let deadline = study.session.deadline
        study.greet()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(study.audio.captionCue, "poke")
        XCTAssertEqual(study.audio.caption, L10n.voice("poke", companion: .mochi))
        XCTAssertEqual(study.session.deadline, deadline)
    }

    func testLayeredDuoAssetsAreBundledForEveryCompanion() throws {
        for companion in Companion.allCases {
            let sprite = try XCTUnwrap(UIImage(named: companion.duoSprite))
            XCTAssertGreaterThan(sprite.size.width, 1000)
            XCTAssertEqual(Int(sprite.size.width) % 2, 0)
        }
        for room in DuoRoom.allCases {
            let background = try XCTUnwrap(UIImage(named: room.asset))
            XCTAssertEqual(background.size.width / background.size.height, 1.5, accuracy: 0.001)
        }
        for size in [CGSize(width: 656, height: 340), CGSize(width: 744, height: 400)] {
            let width = min(520, max(280, size.width * 0.56))
            let host = UIHostingController(rootView:
                TimerPanel(compact: true, clockHeight: min(132, max(76, (width - 82) * 96 / 304)), dense: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.dynamicTypeSize, .large)
                    .environmentObject(study))
            let measured = host.sizeThatFits(in: CGSize(width: width, height: 1000))
            XCTAssertLessThanOrEqual(measured.height + 16, size.height)
        }
    }

    func testTabletopArtworkAndLiveTimerSurviveCompanionAndTextSizeChanges() async throws {
        XCTAssertEqual(Companion.tabletopCompanions, Companion.allCases)
        for name in Companion.tabletopCompanions.compactMap({ $0.tabletopArt?.asset }) {
            let image = try XCTUnwrap(UIImage(named: name))
            XCTAssertEqual(image.size.width / image.size.height, 1.5, accuracy: 0.001)
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let sizes = TextSizeProbe()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView:
            TextSizeProbeView(sizes: sizes, previewTabletop: true)
                .environmentObject(study)
                .environmentObject(PurchaseStore())
                .environmentObject(study.audio))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKey() }
        study.primaryAction()
        try await waitForFocusStart()
        let deadline = try XCTUnwrap(study.session.deadline)
        for companion in Companion.free {
            study.select(companion)
            for size in [DynamicTypeSize.large, .accessibility5] {
                sizes.value = size
                window.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(120))
                XCTAssertEqual(study.companion, companion)
                XCTAssertEqual(study.session.deadline, deadline)
            }
        }
    }
}

@MainActor
private final class TextSizeProbe: ObservableObject {
    @Published var value: DynamicTypeSize = .large
}

private struct TextSizeProbeView: View {
    @ObservedObject var sizes: TextSizeProbe
    var previewTabletop = false
    var body: some View { StudyView(previewTabletop: previewTabletop).environment(\.dynamicTypeSize, sizes.value) }
}
