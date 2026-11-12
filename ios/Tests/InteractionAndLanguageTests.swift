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
    #expect(landscape.frame.minY == 16)
    #expect(landscape.frame.maxX < fold.minX)
    #expect(!landscape.frame.intersects(rail))
    let closedRail = CGRect(x: 382, y: 0, width: 84, height: 174)
    let camera = CGRect(x: 400, y: 29, width: 37, height: 37)
    let closed = TabletopHeaderLayout(width: 466, topInset: 0, headerHeight: 56,
                                     occlusions: [camera, closedRail])
    #expect(closed.frame.minY == 16)
    #expect(closed.frame.maxY < closedRail.maxY)
    #expect(!closed.frame.intersects(camera))
    #expect(closed.frame.width >= 300)
    #expect(!closed.frame.intersects(closedRail))
    let leftRail = CGRect(x: 0, y: 0, width: 84, height: 82)
    let rotated = TabletopHeaderLayout(width: 678, topInset: 0, headerHeight: 56,
                                      occlusions: [leftRail])
    #expect(rotated.frame.midY == 48)
    #expect(rotated.frame.minX > leftRail.maxX)
    #expect(!rotated.frame.intersects(leftRail))
}

@Test func devicePerchesKeepSeatsRegisteredAndBothPosesInsideTheStage() {
    for size in [CGSize(width: 320, height: 300), CGSize(width: 393, height: 390),
                 CGSize(width: 360, height: 200), CGSize(width: 600, height: 780),
                 CGSize(width: 760, height: 600)] {
        let ledge = size.height * 0.72
        for companion in Companion.allCases {
            let frame = ShelfComposition(viewport: size, stage: size, shelfY: ledge,
                minimumY: 24, maximumY: size.height - 8).frame(companion: companion)
            #expect(abs(frame.minY + frame.height * CompanionSpriteRegistration(companion).seat - ledge) < 0.001)
            for poked in [false, true] {
                let bounds = DeviceRoomSprite.bounds(companion: companion, poked: poked)
                #expect(frame.minX + bounds.minX * frame.width >= 0)
                #expect(frame.minX + bounds.maxX * frame.width <= size.width)
                #expect(frame.minY + bounds.minY * frame.height >= 23.99)
                #expect(frame.minY + bounds.maxY * frame.height <= size.height - 7.99)
            }
        }
    }
}

@Test func reusedRoomArchitectureCoversTheStageWithoutStretching() {
    for size in [CGSize(width: 393, height: 852), CGSize(width: 852, height: 393),
                 CGSize(width: 1024, height: 1366), CGSize(width: 1366, height: 1024),
                 CGSize(width: 375, height: 1024)] {
        let format = DeviceRoomFormat.resolve(size: size, isPad: true)
        let ledge = size.height * (format.isLandscape ? 0.65 : 0.46)
        for room in DuoRoom.allCases {
            let frame = format.imageFrame(size: size, ledgeY: ledge, room: room,
                characterX: size.width * (format.isLandscape ? 0.23 : 0.5))
            #expect(format.asset(room: room) == room.asset)
            #expect(abs(frame.width / frame.height - 1.5) < 0.001)
            #expect(frame.minX <= 0.001 && frame.maxX >= size.width - 0.001)
            #expect(frame.minY <= 0.001 && frame.maxY > ledge)
            #expect(abs(frame.minY + frame.height * room.perchFraction - ledge) < 0.001)
        }
    }
}

@Test func shelfPreviewsRegisterEverySeatAtThumbnailAndPackSizes() {
    for size in [CGSize(width: 56, height: 56), CGSize(width: 78, height: 88),
                 CGSize(width: 100, height: 220), CGSize(width: 180, height: 340)] {
        let ledge = size.height * 0.70
        for companion in Companion.allCases {
            let frame = DeviceRoomSprite.perchedFrame(companion: companion,
                width: size.width, height: size.height, ledgeY: ledge,
                horizontalInset: min(12, size.width * 0.08), topInset: 6, bottomInset: 4)
            #expect(abs(frame.minY + frame.height * CompanionSpriteRegistration(companion).seat - ledge) < 0.001)
            for poked in [false, true] {
                let bounds = DeviceRoomSprite.bounds(companion: companion, poked: poked)
                #expect(frame.minX + bounds.minX * frame.width >= 0)
                #expect(frame.minX + bounds.maxX * frame.width <= size.width)
                #expect(frame.minY + bounds.minY * frame.height >= 5.99)
                #expect(frame.minY + bounds.maxY * frame.height <= size.height - 3.99)
            }
        }
    }
}

struct ShelfReferenceFile: Decodable {
    struct Reference: Decodable {
        let scenario: String
        let companion: String
        let viewport: [Double]
        let stage: [Double]
        let shelfY: Double
        let minimumY: Double
        let referenceFrame: [Double]
        let kind: String
        let confirmed: Bool
    }
    let references: [Reference]
}

@Test func automaticShelfFramingMatchesApprovedReferenceProportions() throws {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Verification/ShelfCalibration/references.json")
    let refs = try JSONDecoder().decode(ShelfReferenceFile.self, from: Data(contentsOf: source)).references
    #expect(refs.count == 144)
    #expect(refs.filter(\.confirmed).count == 96)
    #expect(refs.filter { $0.scenario.hasPrefix("max") || $0.scenario.hasPrefix("phone") }.allSatisfy { !$0.confirmed })
    var sizeErrors: [Double] = []
    var centerErrors: [Double] = []
    for ref in refs where ref.confirmed {
        let companion = try #require(Companion(rawValue: ref.companion))
        let composition = ShelfComposition(viewport: CGSize(width: ref.viewport[0], height: ref.viewport[1]),
            stage: CGSize(width: ref.stage[0], height: ref.stage[1]), shelfY: ref.shelfY,
            minimumY: ref.minimumY, maximumY: ref.stage[1] + 32)
        let frame = composition.frame(companion: companion)
        let target = CGRect(x: ref.referenceFrame[0], y: ref.referenceFrame[1],
                            width: ref.referenceFrame[2], height: ref.referenceFrame[3])
        let error = abs(frame.height / target.height - 1)
        let bounds = DeviceRoomSprite.bounds(companion: companion, poked: false)
            .union(DeviceRoomSprite.bounds(companion: companion, poked: true))
        let centerError = abs(frame.minY + bounds.midY * frame.height - target.minY - bounds.midY * target.height) / target.height
        let horizontalError = abs(frame.minX + bounds.midX * frame.width - target.minX - bounds.midX * target.width) / target.height
        sizeErrors.append(error); centerErrors.append(centerError)
        #expect(horizontalError <= 0.10, "\(ref.scenario) / \(companion): horizontal-center error \(horizontalError)")
        #expect(error <= 0.10, "\(ref.scenario) / \(companion): size error \(error)")
        #expect(centerError <= 0.10, "\(ref.scenario) / \(companion): vertical-center error \(centerError)")
        #expect(abs(frame.minY + ShelfCharacterMetrics(companion).seatY * frame.height - ref.shelfY) < 0.001)
    }
    print("Confirmed shelf references: \(sizeErrors.count), mean size error \(sizeErrors.reduce(0,+)/Double(sizeErrors.count)), max size error \(sizeErrors.max() ?? 0), max vertical-center error \(centerErrors.max() ?? 0)")
}

@Test func shelfSolverFitsUnseenWindowsAndResizesContinuously() {
    for companion in Companion.allCases {
        var previousLandscape: CGFloat?
        for width in stride(from: 780.0, through: 1500.0, by: 5) {
            let stage = CGSize(width: width * 0.46, height: 540)
            let geometry = ShelfComposition(viewport: CGSize(width: width, height: 650), stage: stage,
                shelfY: 320, minimumY: 0, maximumY: 572)
            let frame = geometry.frame(companion: companion)
            if let previousLandscape { #expect(abs(frame.height / previousLandscape - 1) < 0.04) }
            previousLandscape = frame.height
            #expect(abs(frame.minY + frame.height * ShelfCharacterMetrics(companion).seatY - 320) < 0.001)
        }
        var previous: CGFloat?
        for width in stride(from: 320.0, through: 850.0, by: 5) {
            let stage = CGSize(width: min(760, width), height: 430)
            let geometry = ShelfComposition(viewport: CGSize(width: width, height: 1000), stage: stage,
                shelfY: 300, minimumY: 0, maximumY: 462)
            let frame = geometry.frame(companion: companion)
            if let previous { #expect(abs(frame.height / previous - 1) < 0.04) }
            previous = frame.height
            #expect(abs(frame.width / frame.height - (companion == .wisp ? 0.75 : 1.5)) < 0.001)
            for poked in [false, true] {
                let bounds = DeviceRoomSprite.bounds(companion: companion, poked: poked)
                #expect(frame.minX + bounds.minX * frame.width >= 11.99)
                #expect(frame.minX + bounds.maxX * frame.width <= stage.width - 11.99)
                #expect(frame.minY + bounds.minY * frame.height >= -0.01)
                #expect(frame.minY + bounds.maxY * frame.height <= 462.01)
            }
        }
    }
}

@Test func hingePaintedShelfAndSpriteUseTheSameLandmark() {
    for size in [CGSize(width: 669, height: 951), CGSize(width: 760, height: 1100)] {
        let hinge = size.height * 0.5
        for companion in Companion.allCases {
            let room = companion.duoRoom
            let painting = room.hingeFrame(width: size.width, hingeY: hinge)
            let frame = CompanionArtworkLayout.seated(hingeY: hinge)
                .frame(companion: companion, width: size.width, height: hinge + 200, viewport: size)
            #expect(abs(painting.minY + painting.height * room.ledgeFraction - hinge) < 0.001)
            #expect(abs(frame.minY + frame.height * ShelfCharacterMetrics(companion).seatY
                - painting.minY - painting.height * room.perchFraction) < 0.001)
        }
    }
}

@Test func narrowPhonePreservesMochisSmallerOpticalProportions() {
    // A tall screen previously bypassed Mochi's 0.74 weight and substituted
    // a generic 500-point ceiling, making it much larger than the approved pets.
    for viewport in [CGSize(width: 393, height: 852), CGSize(width: 440, height: 956),
                     CGSize(width: 956, height: 440)] {
        let stage = CGSize(width: 440, height: 400)
        let composition = ShelfComposition(viewport: viewport, stage: stage, shelfY: 300,
            minimumY: 0, maximumY: 432)
        let mochi = composition.frame(companion: .mochi)
        let jun = composition.frame(companion: .jun)
        #expect(mochi.height / jun.height < 0.80)
        #expect(mochi.height < 290)
        #expect(abs(mochi.minY + mochi.height * ShelfCharacterMetrics(.mochi).seatY - 300) < 0.001)
    }
}
