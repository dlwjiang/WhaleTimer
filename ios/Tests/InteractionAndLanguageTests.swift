import Foundation
import CoreGraphics
import Testing
@testable import BankeCore

@Test func tabletopArtTracksHingeWithoutStretchingOrCoveringTimer() {
    #expect(Companion.tabletopCompanions == Companion.allCases)
    for size in [CGSize(width: 760, height: 860), CGSize(width: 900, height: 620), CGSize(width: 600, height: 1000)] {
        let division = CGRect(x: 0, y: size.height * 0.47, width: size.width, height: 20)
        let layout = TabletopSceneLayout(size: size, division: division)
        #expect(layout.sceneHeight >= division.maxY)
        #expect(layout.timerHeight > 0)
        #expect(abs(layout.timerTop + layout.timerHeight - size.height) < 0.001)
        #expect(layout.timerTop >= division.maxY)
        #expect(layout.timerTop < layout.sceneHeight)
        for companion in Companion.tabletopCompanions {
            let art = TabletopSceneLayout.artFrame(companion: companion, width: size.width, hingeY: layout.hingeY)
            #expect(abs(art.width / art.height - 1.5) < 0.001)
            // The room covers the full upper canvas, including the glass header.
            #expect(art.minY <= 0.001)
            #expect(art.minX <= 0.001)
            #expect(art.maxX >= size.width - 0.001)
            #expect(art.maxY < layout.sceneHeight)
            #expect(abs(art.minY + art.height * TabletopSceneLayout.ledgeFraction(companion) - division.midY) < 0.001)
        }
    }
}

@Test func tabletopTimerStaysFixedWhenCompanionsChange() {
    let size = CGSize(width: 760, height: 1000)
    let division = CGRect(x: 0, y: 460, width: 760, height: 16)
    let baseline = TabletopSceneLayout(size: size, division: division)
    for companion in Companion.allCases {
        let layout = TabletopSceneLayout(size: size, division: division, companion: companion)
        #expect(layout.timerTop == baseline.timerTop)
        #expect(layout.timerHeight == baseline.timerHeight)
        #expect(layout.clockHeight(width: size.width) == baseline.clockHeight(width: size.width))
        #expect(layout.timerTop < layout.sceneHeight)
        #expect(layout.clockHeight(width: size.width) > 132)
        #expect(layout.clockHeight(width: size.width) + 184 <= layout.timerHeight)
    }
}

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
    #expect(settings.shortBreaksEnabled && settings.longBreaksEnabled)
    #expect(settings.focusMinutes == 50)
    #expect(settings.notificationsEnabled && settings.keepAwake)
}

@Test func tabletopHeaderSharesStatusRowWithoutCoveringNativeControls() {
    let status = CGRect(x: 490, y: 16, width: 134, height: 54)
    let layout = TabletopHeaderLayout(width: 656, topInset: 76, headerHeight: 56, occlusions: [status])
    #expect(layout.frame.minY < 76)
    #expect(layout.frame.midY == status.midY)
    #expect(layout.frame.height == status.height)
    #expect(layout.frame.width >= 320)
    #expect(!layout.frame.intersects(status))
    #expect(layout.frame.maxX <= 656 - 164)
    let camera = CGRect(x: 210, y: 0, width: 210, height: 85)
    let obstructed = TabletopHeaderLayout(width: 656, topInset: 76, headerHeight: 56, occlusions: [status, camera])
    #expect(!obstructed.frame.intersects(camera))
    #expect(!obstructed.frame.intersects(status))
}

@Test func tabletopHeaderTracksNativeControlRowRatherThanSafeAreaMidpoint() {
    for centerY in [CGFloat(48), 56, 64] {
        let control = CGRect(x: 620, y: centerY - 22, width: 44, height: 44)
        let layout = TabletopHeaderLayout(width: 760, topInset: 96, headerHeight: 56,
                                         occlusions: [control])
        #expect(layout.frame.midY == centerY)
        #expect(!layout.frame.intersects(control))
    }
    let fallback = TabletopHeaderLayout(width: 760, topInset: 76, headerHeight: 56, occlusions: [])
    #expect(fallback.frame.midY == 48)
}

@Test func tabletopHeaderKeepsNarrowAndAccessibleLayoutsBelowStatusArea() {
    let narrow = TabletopHeaderLayout(width: 390, topInset: 59, headerHeight: 56, occlusions: [])
    #expect(narrow.frame.minY >= 59)
    #expect(narrow.frame.maxX <= 390)
    let accessible = TabletopHeaderLayout(width: 656, topInset: 76, headerHeight: 120,
        occlusions: [], allowsInline: false)
    #expect(accessible.frame.minY >= 76)
    #expect(accessible.frame.height == 120)
}

@Test func tabletopHeaderDoesNotExpandToFillSystemControlClearance() {
    // Actual Duo reserved region includes the entire status-area clearance.
    let clearance = CGRect(x: 525, y: 0, width: 144, height: 82)
    let layout = TabletopHeaderLayout(width: 669, topInset: 82, headerHeight: 56,
                                     occlusions: [clearance])
    #expect(layout.frame.height == 52)
    #expect(layout.frame.midY == 48)
    #expect(!layout.frame.intersects(clearance))
}

@Test func duoHeaderHandlesRightStatusRailAndNeverCrossesVerticalFold() {
    let rail = CGRect(x: 867, y: 0, width: 84, height: 124)
    let fold = CGRect(x: 455.5, y: 0, width: 40, height: 669)
    let landscape = TabletopHeaderLayout(width: 951, topInset: 0, headerHeight: 56,
                                        occlusions: [rail], division: fold)
    #expect(landscape.frame.height == 52)
    #expect(landscape.frame.midY == 62)
    #expect(landscape.frame.minY >= 24)
    #expect(landscape.frame.maxX < fold.minX)
    #expect(!landscape.frame.intersects(rail))
    let closedRail = CGRect(x: 382, y: 0, width: 84, height: 174)
    let camera = CGRect(x: 400, y: 29, width: 37, height: 37)
    let closed = TabletopHeaderLayout(width: 466, topInset: 0, headerHeight: 56,
                                     occlusions: [camera, closedRail])
    #expect(closed.frame.midY == 112)
    #expect(closed.frame.width >= 300)
    #expect(!closed.frame.intersects(closedRail))
    let leftRail = CGRect(x: 0, y: 0, width: 84, height: 82)
    let rotated = TabletopHeaderLayout(width: 678, topInset: 0, headerHeight: 56,
                                      occlusions: [leftRail])
    #expect(rotated.frame.midY == 48)
    #expect(rotated.frame.minX > leftRail.maxX)
    #expect(!rotated.frame.intersects(leftRail))
}
