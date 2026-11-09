import Foundation
import Testing
@testable import BankeCore

@Test func cancelledOrPartialResetNeverResets() {
    #expect(!InteractionGeometry.shouldReset(fraction: 0.879))
    #expect(InteractionGeometry.shouldReset(fraction: 0.88))
    #expect(!InteractionGeometry.shouldReset(fraction: 1, cancelled: true))
    #expect(InteractionGeometry.resetFraction(translation: -90, travel: 100) == 0)
    #expect(InteractionGeometry.resetFraction(translation: 200, travel: 100) == 1)
    #expect(InteractionGeometry.resetFraction(translation: 200, travel: 0) == 0)
}

@Test func carouselDistinguishesScrollFlickAndIncompleteDrag() {
    #expect(InteractionGeometry.carouselDirection(x: -80, y: 2, predictedX: -80, width: 390) == 1)
    #expect(InteractionGeometry.carouselDirection(x: 80, y: 2, predictedX: 80, width: 390) == -1)
    #expect(InteractionGeometry.carouselDirection(x: -80, y: 100, predictedX: -200, width: 390) == 0)
    #expect(InteractionGeometry.carouselDirection(x: -31, y: 0, predictedX: -300, width: 390) == 0)
    #expect(InteractionGeometry.carouselDirection(x: -33, y: 0, predictedX: -100, width: 390) == 1)
    #expect(InteractionGeometry.carouselDirection(x: -33, y: 0, predictedX: 100, width: 390) == 0)
    #expect(CarouselFrame(offset: 0).scale == 1)
    #expect(CarouselFrame(offset: 0).opacity == 1)
    #expect(CarouselFrame(offset: 1).opacity == 0)
    #expect(abs(CarouselFrame(offset: -0.5).x + CarouselFrame(offset: 0.5).x) < 0.00001)
}

@Test func localeResolutionHonorsUserChoiceAndRegionalPreferences() {
    #expect(AppLanguage.resolve(preference: "ja", preferredLanguages: ["en-US"]) == .ja)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["zh-TW"]) == .traditionalChinese)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["zh-HK"]) == .traditionalChinese)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["zh-CN"]) == .simplifiedChinese)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["pt-PT"]) == .brazilianPortuguese)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["es-MX"]) == .es)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["ar", "de-DE"]) == .de)
    #expect(AppLanguage.resolve(preference: "system", preferredLanguages: ["ar"]) == .en)
    #expect(AppLanguage.traditionalChinese.voiceDirectory == AppLanguage.simplifiedChinese.voiceDirectory)
}

@Test func openingCountdownDoesNotSpendFocusTimeAndCannotFinishAfterCancellation() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var state = StudyState()
    state.session.beginPreparation()
    #expect(state.session.status == .preparing)
    #expect(state.session.deadline == nil)
    state.reconcile(at: now.addingTimeInterval(100))
    #expect(state.session.remaining == 1500)
    #expect(state.completedInCycle == 0)
    let restored = StudyState.restore(try JSONEncoder().encode(state))
    #expect(restored.session.status == .preparationPaused)
    state.session.pause(at: now)
    state.session.finishPreparation(at: now)
    #expect(state.session.status == .preparationPaused)
    state.session.start(at: now)
    #expect(state.session.deadline == nil)
    state.session.beginPreparation()
    #expect(state.session.status == .preparing)
    state.reset()
    state.session.finishPreparation(at: now)
    #expect(state.session.status == .ready)
    state.session.beginPreparation()
    state.session.finishPreparation(at: now)
    #expect(state.session.deadline == now.addingTimeInterval(1500))
}

@Test func oldSettingsPreserveMuteAndGainSeparateAudioControls() throws {
    let data = Data(#"{"focusMinutes":50,"shortBreakMinutes":10,"longBreakMinutes":20,"soundEnabled":false,"notificationsEnabled":true,"keepAwake":true}"#.utf8)
    let settings = try JSONDecoder().decode(TimerSettings.self, from: data)
    #expect(!settings.soundEnabled)
    #expect(settings.effectsEnabled && settings.voicesEnabled)
    #expect(settings.focusMinutes == 50)
    #expect(settings.notificationsEnabled && settings.keepAwake)
}
