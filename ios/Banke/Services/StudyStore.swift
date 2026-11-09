import SwiftUI
import UserNotifications
import AVFoundation

@MainActor
final class StudyStore: ObservableObject {
    @Published private(set) var state: StudyState
    @Published var notificationMessage: String?
    @Published var storageMessage: String?
    private let purchases: PurchaseStore
    private let defaults: UserDefaults
    private let storageKey = "banke.native.study.v1"
    private var notificationTask: Task<Void, Never>?
    let audio = CompanionAudio()
    private var preparationTask: Task<Void, Never>?
    private var lastCountdownSecond: Int?

    init(purchases: PurchaseStore, defaults: UserDefaults = .standard) {
        self.purchases = purchases
        self.defaults = defaults
        state = StudyState.restore(defaults.data(forKey: storageKey))
        state.reconcile(at: Date())
        save()
        scheduleNotification()
        audio.onInterruption = { [weak self] in self?.cancelPreparation() }
    }

    var session: FocusSession { state.session }
    var companion: Companion { state.companion.isAvailable(in: purchases.ownedProductIDs) ? state.companion : .mochi }

    func reconcileCompanionAccess() {
        guard purchases.hasLoadedEntitlements else { return }
        if !state.companion.isAvailable(in: purchases.ownedProductIDs) {
            state.companion = .mochi
            didChange()
        } else { objectWillChange.send() }
    }

    private var audibleVoice: Bool { state.settings.soundEnabled && state.settings.voicesEnabled }
    private var audibleEffects: Bool { state.settings.soundEnabled && state.settings.effectsEnabled }

    func tick(now: Date = Date(), audible: Bool = true) {
        // Calling a mutating method on @Published state publishes even when it
        // returns without changing anything. Idle polling must stay read-only.
        guard session.status == .running else { return }
        if state.reconcile(at: now) {
            save(); scheduleNotification()
            if audible {
                audio.effect("bell", enabled: audibleEffects)
                if session.phase == .focus && state.nextPhase == .focus {
                    // The bundled completion line invites a break; use a neutral caption instead.
                    audio.say("focusComplete", companion: companion, audible: false,
                              captionOverride: L10n.text("Well done! Ready when you are."))
                } else {
                    audio.say(session.phase == .focus ? "focusComplete" : "breakComplete", companion: companion, audible: audibleVoice)
                }
            }
        } else if session.status == .running {
            let second = Int(ceil(session.remaining))
            if audible, (1...5).contains(second), second != lastCountdownSecond {
                audio.say(String(second), companion: companion, audible: audibleVoice)
            }
            lastCountdownSecond = second
        }
        updateIdleTimer()
    }

    func primaryAction() {
        let now = Date()
        tick(now: now, audible: false)
        switch session.status {
        case .running, .preparing:
            cancelPreparation()
            state.session.pause(at: now)
            audio.effect("pause", enabled: audibleEffects)
            audio.say("pause", companion: companion, audible: audibleVoice)
        case .paused:
            state.session.start(at: now)
            audio.effect("play", enabled: audibleEffects)
            audio.say("resume", companion: companion, audible: audibleVoice)
        case .preparationPaused:
            beginSession()
        case .ready:
            beginSession()
        case .complete:
            lastCountdownSecond = nil
            state.advance()
            if session.phase == .focus { beginSession() }
            else {
                state.session.start(at: now)
                audio.effect("play", enabled: audibleEffects)
            }
        }
        didChange()
    }

    private func beginSession() {
        lastCountdownSecond = nil
        audio.stopSpeech()
        audio.effect("play", enabled: audibleEffects)
        // Short/long breaks begin directly. A fresh focus gets the web's spoken lead-in.
        guard session.phase == .focus else { state.session.start(at: Date()); return }
        state.session.beginPreparation()
        preparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for cue in ["3", "2", "1", "go"] {
                guard !Task.isCancelled, self.session.status == .preparing else { return }
                let started = Date()
                _ = await self.audio.speak(cue, companion: self.companion, audible: self.audibleVoice)
                guard !Task.isCancelled, self.session.status == .preparing else { return }
                let beat = cue == "go" ? 0.0 : max(0, 0.8 - Date().timeIntervalSince(started))
                do { try await Task.sleep(for: .seconds(beat)) } catch { return }
            }
            guard !Task.isCancelled, self.session.status == .preparing else { return }
            self.state.session.finishPreparation(at: Date())
            self.preparationTask = nil
            self.didChange()
        }
    }

    private func cancelPreparation() {
        preparationTask?.cancel(); preparationTask = nil
        if session.status == .preparing { state.session.pause(at: Date()); didChange() }
        audio.stopSpeech()
    }

    func reset() {
        cancelPreparation(); state.reset(); lastCountdownSecond = nil
        audio.effect("pause", enabled: audibleEffects)
        audio.say("reset", companion: companion, audible: audibleVoice)
        didChange()
    }

    func skipBreak() {
        guard session.phase != .focus || session.status == .complete else { return }
        reset()
    }

    func select(_ companion: Companion) {
        guard companion.isAvailable(in: purchases.ownedProductIDs), companion != self.companion else { return }
        tick()
        state.companion = companion
        didChange()
    }

    func greet() {
        guard session.status != .preparing else { return }
        audio.say("greeting", companion: companion, audible: audibleVoice)
    }
    func previewVoice(_ companion: Companion) {
        guard session.status != .preparing else { return }
        audio.say("greeting", companion: companion, audible: audibleVoice, preview: true)
    }
    func stopVoicePreview() { if audio.previewing { audio.stopSpeech() } }
    func languageChanged() {
        // Keep a running deadline intact; an interrupted lead-in remains paused.
        cancelPreparation(); notificationMessage = nil; scheduleNotification(); objectWillChange.send()
    }

    func updateSettings(_ settings: TimerSettings) {
        if state.settings.soundEnabled != settings.soundEnabled || state.settings.voicesEnabled != settings.voicesEnabled {
            audio.stop()
        }
        if !settings.effectsEnabled { audio.stopEffects() }
        state.updateSettings(settings)
        didChange()
    }

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            state.settings.notificationsEnabled = granted
            notificationMessage = granted ? nil : "Notifications are off. Enable them in iOS Settings."
            didChange()
        } catch {
            state.settings.notificationsEnabled = false
            notificationMessage = "Couldn’t enable reminders. Please try again."
            didChange()
        }
    }

    func foreground() {
        tick(audible: false)
        scheduleNotification()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func background() {
        cancelPreparation(); audio.stop()
        tick(audible: false)
        save()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func save() {
        do {
            defaults.set(try JSONEncoder().encode(state), forKey: storageKey)
            storageMessage = nil
        } catch {
            storageMessage = "Couldn’t save the latest session. Keep the app open and try again."
        }
    }

    private func didChange() {
        save()
        scheduleNotification()
        updateIdleTimer()
    }

    private func updateIdleTimer() {
        let keepAwake = state.settings.keepAwake && session.status == .running
        if UIApplication.shared.isIdleTimerDisabled != keepAwake {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
    }

    private func scheduleNotification() {
        notificationTask?.cancel()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard state.settings.notificationsEnabled, session.status == .running, let deadline = session.deadline else { return }
        let identifier = "banke.\(UUID().uuidString)"
        let content = UNMutableNotificationContent()
        content.title = L10n.text(session.phase == .focus ? "A little progress, together." : "Ready for another little chapter?")
        if session.phase == .focus {
            let next = state.settings.phaseAfterFocus(completedInCycle: state.completedInCycle + 1)
            content.body = next == .focus
                ? L10n.text("Your focus session is complete. %@ is ready when you are.", companion.name)
                : L10n.text("%@ is ready for a break. Your focus session is complete.", companion.name)
        } else {
            content.body = L10n.text("Your break is over. %@ is waiting in your study corner.", companion.name)
        }
        if audibleEffects { content.sound = UNNotificationSound(named: UNNotificationSoundName("completion.wav")) }
        notificationTask = Task { [weak self] in
            let settings = await center.notificationSettings()
            guard !Task.isCancelled else { return }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                self?.notificationMessage = "Notifications are off. Enable them in iOS Settings."
                return
            }
            let interval = deadline.timeIntervalSinceNow
            guard interval > 0 else { return }
            let request = UNNotificationRequest(identifier: identifier, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false))
            do {
                try await center.add(request)
                // A pause/reset may happen while add is in flight. Remove only this task’s request.
                if Task.isCancelled { center.removePendingNotificationRequests(withIdentifiers: [identifier]) }
            } catch {
                if !Task.isCancelled { self?.notificationMessage = "Couldn’t schedule this reminder. Your timer still works." }
            }
        }
    }

}
