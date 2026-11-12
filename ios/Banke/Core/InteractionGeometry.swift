import Foundation
import CoreGraphics

/// Four purpose-composed formats, also chosen by window shape in iPad multitasking.
enum DeviceRoomFormat: String, CaseIterable {
    case phone = "phone"
    case phoneLandscape = "phone-landscape"
    case padPortrait = "pad-portrait"
    case padLandscape = "pad-landscape"

    var isLandscape: Bool { self == .phoneLandscape || self == .padLandscape }
    static func resolve(size: CGSize, isPad: Bool) -> Self {
        let ratio = size.width / max(1, size.height)
        if ratio > 1 { return ratio > 1.75 ? .phoneLandscape : .padLandscape }
        return isPad && ratio >= 0.6 ? .padPortrait : .phone
    }
    // Reuse the six painted Duo rooms; crop the architecture, never the ledge.
    func asset(room: DuoRoom) -> String { room.asset }
    var aspect: CGFloat { 1.5 }
    func imageFrame(size: CGSize, ledgeY: CGFloat, room: DuoRoom, characterX: CGFloat) -> CGRect {
        let height = max(size.width * (isLandscape ? 1.3 : 1) / aspect,
                         max(0, ledgeY) / room.perchFraction)
        let width = height * aspect
        // Keep the clear center of the original painting behind the companion.
        let x = min(0, max(size.width - width, characterX - width * (isLandscape ? 0.4 : 0.5)))
        return CGRect(x: x, y: ledgeY - height * room.perchFraction, width: width, height: height)
    }

}

/// Register the bottom of each illustrated ledge to the fold, filling behind the header.
struct TabletopSceneLayout {
    let hingeY: CGFloat
    let sceneHeight: CGFloat
    let timerTop: CGFloat
    let timerHeight: CGFloat

    init(size: CGSize, division: CGRect, companion: Companion = .mochi) {
        let resolvedHingeY = min(size.height, max(0, division.midY))
        hingeY = resolvedHingeY
        let artBottom = Companion.tabletopCompanions.map {
            Self.artFrame(companion: $0, width: size.width, hingeY: resolvedHingeY).maxY
        }.max() ?? hingeY
        sceneHeight = min(size.height, max(division.maxY, artBottom + 12))
        // A fixed lower-pane composition: feet can sit behind the glass, but
        // selecting a taller character must never move or resize the clock.
        let lowerHeight = max(0, size.height - division.maxY)
        timerTop = min(size.height, division.maxY + min(32, lowerHeight * 0.08))
        timerHeight = max(0, size.height - timerTop)
    }

    func clockHeight(width: CGFloat) -> CGFloat {
        let cardWidth = min(900, max(0, width - 40))
        let widthLimit = max(96, (cardWidth - 40 - 42) * 96 / 304)
        // Reserve the phase label, controls, progress bar, padding and gaps.
        // On shallow panes or at accessibility sizes, the panel scrolls from its top.
        return max(96, min(widthLimit, timerHeight - 184))
    }

    static func ledgeFraction(_ companion: Companion) -> CGFloat {
        companion.tabletopArt?.ledgeFraction ?? 0.775
    }

    static func artFrame(companion: Companion, width: CGFloat, hingeY: CGFloat) -> CGRect {
        let fraction = ledgeFraction(companion)
        let upperCoverage: CGFloat = max(0, hingeY) / fraction
        let height: CGFloat = max(0, max(width / 1.5, upperCoverage))
        let artWidth: CGFloat = height * 1.5
        let origin = CGPoint(x: (width - artWidth) / 2, y: hingeY - height * fraction)
        return CGRect(origin: origin, size: CGSize(width: artWidth, height: height))
    }
}

/// The web cylinder uses a 120° orbit with a gentler 54° turn of each portrait.
struct CarouselFrame: Equatable {
    let x: Double
    let scale: Double
    let yaw: Double
    let opacity: Double
    let depth: Double
    init(offset: Double) {
        let angle = offset * 2 * Double.pi / 3
        depth = cos(angle)
        x = sin(angle) * 0.3
        scale = 1 / (1 - (depth - 1) * 0.48)
        yaw = offset * 54
        opacity = abs(offset) > 1.5 ? 0 : min(1, max(0, (depth + 0.25) / 0.75))
    }
}

enum InteractionGeometry {
    static func carouselDirection(x: Double, y: Double, predictedX: Double, width: Double) -> Int {
        guard abs(x) > abs(y) * 1.3 else { return 0 }
        let threshold = max(48, min(90, width * 0.14))
        let flick = abs(x) >= 32 && abs(predictedX) > threshold * 1.5 && predictedX.sign == x.sign
        return abs(x) >= threshold || flick ? (x < 0 ? 1 : -1) : 0
    }
    static func resetFraction(translation: Double, travel: Double) -> Double {
        travel > 0 ? min(1, max(0, translation / travel)) : 0
    }
    static func shouldReset(fraction: Double, cancelled: Bool = false) -> Bool {
        !cancelled && fraction >= 0.88
    }
}

/// Scene registration is kept with the asset identity so every layout uses the same landmarks.
struct TabletopArt {
    let asset: String
    let ledgeFraction: CGFloat
    let mouth: CGPoint
}

enum DuoRoom: String, CaseIterable {
    case window, study, river, cafe, academy, orbit
    var asset: String { "duo-room-\(rawValue)" }
    var landscapeAsset: String { "duo-landscape-\(rawValue)" }
    /// Front of the seat surface, distinct from the bottom edge used by Duo's hinge.
    var perchFraction: CGFloat {
        switch self {
        case .window: 0.710
        case .study: 0.690
        case .river: 0.715
        case .cafe: 0.720
        case .academy: 0.708
        case .orbit: 0.700
        }
    }
    var ledgeFraction: CGFloat {
        switch self {
        case .window: 0.775
        case .study: 0.735
        case .river: 0.789
        case .cafe: 0.784
        case .academy: 0.786
        case .orbit: 0.763
        }
    }
}

extension Companion {
    var duoRoom: DuoRoom {
        switch self {
        case .mochi: .window
        case .pip: .study
        case .pebble: .river
        case .jun, .bean, .maple: .cafe
        case .luna, .atlas, .wisp: .academy
        case .nova, .orbit, .comet: .orbit
        }
    }
    var duoSprite: String { "duo-sprite-\(rawValue)" }
}

extension Companion {
    static var tabletopCompanions: [Companion] { allCases.filter { $0.tabletopArt != nil } }
    var tabletopArt: TabletopArt? {
        let ledge: CGFloat
        let mouth: CGPoint
        switch self {
        case .mochi: ledge = 0.775; mouth = CGPoint(x: 0.53, y: 0.45)
        case .pip: ledge = 0.735; mouth = CGPoint(x: 0.52, y: 0.36)
        case .pebble: ledge = 0.789; mouth = CGPoint(x: 0.47, y: 0.38)
        case .maple: ledge = 0.784; mouth = CGPoint(x: 0.54, y: 0.36)
        case .wisp: ledge = 0.786; mouth = CGPoint(x: 0.53, y: 0.42)
        case .comet: ledge = 0.763; mouth = CGPoint(x: 0.51, y: 0.43)
        case .jun: ledge = 0.784; mouth = CGPoint(x: 0.52, y: 0.405)
        case .bean: ledge = 0.784; mouth = CGPoint(x: 0.54, y: 0.385)
        case .luna: ledge = 0.786; mouth = CGPoint(x: 0.53, y: 0.395)
        case .atlas: ledge = 0.786; mouth = CGPoint(x: 0.55, y: 0.345)
        case .nova: ledge = 0.763; mouth = CGPoint(x: 0.52, y: 0.375)
        case .orbit: ledge = 0.763; mouth = CGPoint(x: 0.53, y: 0.45)
        }
        return TabletopArt(asset: "duo-\(rawValue)", ledgeFraction: ledge, mouth: mouth)
    }
}

/// Fit the header beside the Duo status controls, otherwise retain the safe-area row.
struct TabletopHeaderLayout {
    let frame: CGRect

    init(width: CGFloat, topInset: CGFloat, headerHeight: CGFloat,
         occlusions: [CGRect], division: CGRect? = nil, allowsInline: Bool = true) {
        // Duo rotates the status area between a horizontal capsule and a
        // vertical rail. The rail can be outside the rectangular safe area.
        let statusArea = occlusions.filter {
            ($0.midX > width * 0.6 || $0.midX < width * 0.4)
                && $0.minY >= -1 && $0.maxY <= 210
                && $0.width >= 44 && $0.height > 0
        }.max { $0.width * $0.height < $1.width * $1.height }
        let controlHeight = statusArea?.height ?? 52
        let height = allowsInline ? (controlHeight <= 60 ? max(44, controlHeight) : 52) : max(56, headerHeight)
        let margin: CGFloat = width < 600 ? 16 : 24
        var fallback = CGRect(x: margin, y: max(12, topInset + 6),
                              width: max(0, min(620, width - 2 * margin)), height: height)
        for rect in occlusions.sorted(by: { $0.minY < $1.minY }) where rect.intersects(fallback) {
            fallback.origin.y = rect.maxY + 12
        }
        guard allowsInline, topInset >= 44 || statusArea != nil else { frame = fallback; return }
        let centerY: CGFloat
        if let statusArea {
            if statusArea.height <= 60 {
                centerY = statusArea.midY
            } else if statusArea.height > statusArea.width {
                // A vertical rail includes the camera and status controls. Place
                // our bar at the top beside the rail, not beside its lower clock.
                centerY = max(16, statusArea.minY + 16) + height / 2
            } else {
                centerY = statusArea.maxY - 34
            }
        } else {
            centerY = max(40, topInset - 28)
        }
        let y = max(16, centerY - height / 2)
        let band = CGRect(x: margin, y: y, width: max(0, width - 2 * margin), height: height)
        var obstacles = occlusions
        if let division, division.height > division.width { obstacles.append(division) }
        if statusArea == nil {
            obstacles.append(CGRect(x: max(0, width - 164), y: 0, width: 164,
                                    height: max(topInset, band.maxY)))
        }
        let blocked = obstacles.filter { $0.intersects(band) }.sorted { $0.minX < $1.minX }
        var left = band.minX
        var gaps: [CGRect] = []
        for rect in blocked {
            let right = min(band.maxX, rect.minX - 8)
            if right > left { gaps.append(CGRect(x: left, y: y, width: right - left, height: height)) }
            left = max(left, rect.maxX + 8)
        }
        if left < band.maxX { gaps.append(CGRect(x: left, y: y, width: band.maxX - left, height: height)) }
        if var gap = gaps.first(where: { $0.width >= 300 }) {
            gap.size.width = min(620, gap.width)
            frame = gap
        } else {
            frame = fallback
        }
    }
}

/// Display-specific geometry for the same two-frame companion artwork.
enum CompanionArtworkLayout {
    case seated(hingeY: CGFloat)
    case perched(y: CGFloat)
    case platform(calibrated: Bool)

    func frame(companion: Companion, width: CGFloat, height: CGFloat) -> CGRect {
        let registration = CompanionSpriteRegistration(companion)
        switch self {
        case .seated(let hingeY):
            let baselineHeight = min(max(width / 1.5, hingeY / 0.78), hingeY / registration.seat) * registration.scale
            let framing = registration.approvedFraming
            let h = baselineHeight * framing.scale
            return CGRect(x: width / 2 - h * registration.aspect / 2 + framing.x * width,
                          y: hingeY - h * registration.seat + framing.y * hingeY,
                          width: h * registration.aspect, height: h)
        case .perched(let ledgeY):
            return DeviceRoomSprite.perchedFrame(companion: companion, width: width, height: height, ledgeY: ledgeY)
        case .platform(let calibrated):
            let base = DeviceRoomSprite.frame(companion: companion, width: width, floorY: height * 0.87)
            guard calibrated else { return base }
            let framing = companion.landscapeFraming
            let center = CGPoint(x: base.midX + framing.x * width, y: base.midY + framing.y * height)
            let bounds = DeviceRoomSprite.bounds(companion: companion, poked: false)
                .union(DeviceRoomSprite.bounds(companion: companion, poked: true))
            let scale = min(framing.scale, (width - 24) / (base.width * bounds.width),
                            (height - 24) / (base.height * bounds.height))
            var frame = CGRect(x: center.x - base.width * scale / 2,
                               y: center.y - base.height * scale / 2,
                               width: base.width * scale, height: base.height * scale)
            // Preserve calibration where it fits; keep ears and feet in the pane
            // now that every posture uses the same registered illustration.
            let left = frame.minX + bounds.minX * frame.width
            let right = frame.minX + bounds.maxX * frame.width
            let top = frame.minY + bounds.minY * frame.height
            let bottom = frame.minY + bounds.maxY * frame.height
            frame.origin.x += max(0, 12 - left) - max(0, right - width + 12)
            frame.origin.y += max(0, 12 - top) - max(0, bottom - height + 12)
            return frame
        }
    }
}

struct CompanionSpriteRegistration {
    let aspect: CGFloat
    let seat: CGFloat
    let mouth: CGPoint
    let scale: CGFloat
    let approvedFraming: (scale: CGFloat, x: CGFloat, y: CGFloat)
    init(_ companion: Companion, poked: Bool = false) {
        aspect = companion == .wisp ? 0.75 : 1.5
        // Scale about the seat so smaller companions still rest on the ledge.
        switch companion {
        case .atlas: scale = 0.70
        case .mochi, .pebble, .bean, .maple: scale = 0.74
        default: scale = 1
        }
        // User-approved Duo calibration, relative to the original baseline above.
        // Keep this transform after the speech overlay to reproduce the audition
        // exactly. Offsets use pane width and top-to-hinge height, respectively.
        approvedFraming = switch companion {
        case .mochi: (0.70, 0, -0.085)
        case .pip: (0.79, -0.015, -0.015)
        case .pebble: (0.77, 0, -0.080)
        case .jun: (0.83, 0, -0.035)
        case .bean: (0.83, 0, -0.100)
        case .maple: (0.85, 0, -0.105)
        case .luna: (0.74, 0, -0.110)
        case .atlas: (0.93, 0, -0.095)
        case .wisp: (0.75, 0, -0.090)
        case .nova: (0.80, 0, -0.065)
        case .orbit: (0.69, 0, -0.060)
        case .comet: (0.80, 0, -0.090)
        }
        switch companion {
        case .mochi: seat = 0.77; mouth = CGPoint(x: 0.591, y: poked ? 0.401 : 0.388)
        case .pip: seat = 0.72; mouth = CGPoint(x: 0.558, y: 0.327)
        case .pebble: seat = 0.78; mouth = CGPoint(x: poked ? 0.460 : 0.464, y: poked ? 0.345 : 0.328)
        case .maple: seat = 0.74; mouth = CGPoint(x: poked ? 0.581 : 0.576, y: poked ? 0.335 : 0.328)
        case .bean: seat = 0.85; mouth = CGPoint(x: 0.600, y: poked ? 0.397 : 0.375)
        case .jun: seat = 0.72; mouth = CGPoint(x: 0.545, y: poked ? 0.350 : 0.343)
        case .wisp: seat = 0.72; mouth = CGPoint(x: poked ? 0.562 : 0.613, y: 0.411)
        case .luna: seat = 0.70; mouth = CGPoint(x: 0.548, y: 0.312)
        case .atlas: seat = 0.93; mouth = CGPoint(x: 0.566, y: poked ? 0.315 : 0.298)
        case .nova: seat = 0.73; mouth = CGPoint(x: 0.552, y: poked ? 0.343 : 0.335)
        case .orbit: seat = 0.76; mouth = CGPoint(x: 0.560, y: 0.433)
        case .comet: seat = 0.74; mouth = CGPoint(x: 0.535, y: poked ? 0.436 : 0.425)
        }
    }
}

extension Companion {
    /// Approved for the side-by-side Duo rooms. Offsets are fractions of the
    /// character pane; these multiply/offset the existing platform baseline.
    var landscapeFraming: (scale: CGFloat, x: CGFloat, y: CGFloat) {
        switch self {
        case .mochi: (0.68, 0.025, 0.100)
        case .pip: (1.08, 0, -0.025)
        case .pebble: (0.93, 0, 0)
        case .jun: (1.13, 0.025, -0.005)
        case .bean: (0.77, 0.015, 0.095)
        case .maple: (0.92, 0, 0.040)
        case .luna: (1, 0, 0)
        case .atlas: (0.78, 0, 0.070)
        case .wisp: (0.90, 0, 0.010)
        case .nova: (1.11, 0, 0.010)
        case .orbit: (0.92, 0.020, 0.060)
        case .comet: (1.11, 0, -0.035)
        }
    }

}

/// Alpha bounds of both registered sprite cells. One fixed frame contains both
/// expressions, so a poke changes the illustration without recentering the body.
enum DeviceRoomSprite {
    static func bounds(companion: Companion, poked: Bool) -> CGRect { allBounds(companion)[poked ? 1 : 0] }
    static func perchedFrame(companion: Companion, width: CGFloat, height: CGFloat, ledgeY: CGFloat,
                             horizontalInset: CGFloat = 44, topInset: CGFloat = 24,
                             bottomInset: CGFloat = 8) -> CGRect {
        let union = allBounds(companion)[0].union(allBounds(companion)[1])
        let registration = CompanionSpriteRegistration(companion)
        let seat = registration.seat
        let h = max(1, min(500,
            max(1, width - horizontalInset * 2) / (registration.aspect * union.width),
            max(1, ledgeY - topInset) / max(0.01, seat - union.minY),
            max(1, height - bottomInset - ledgeY) / max(0.01, union.maxY - seat)))
        let w = h * registration.aspect
        return CGRect(x: width / 2 - union.midX * w, y: ledgeY - seat * h, width: w, height: h)
    }
    static func frame(companion: Companion, width: CGFloat, floorY: CGFloat) -> CGRect {
        let poses = allBounds(companion)
        let union = poses[0].union(poses[1])
        let aspect: CGFloat = companion == .wisp ? 0.75 : 1.5
        let h = min(500, max(64, width - 88) / (aspect * union.width), max(64, floorY - 24) / union.height)
        let w = h * aspect
        return CGRect(x: width / 2 - union.midX * w,
                      y: floorY - union.maxY * h, width: w, height: h)
    }
    private static func allBounds(_ companion: Companion) -> [CGRect] {
        switch companion {
        case .atlas: [CGRect(x: 0.255064, y: 0.026243, width: 0.448435, height: 0.907459),
            CGRect(x: 0.255064, y: 0.012431, width: 0.456722, height: 0.921271)]
        case .bean: [CGRect(x: 0.240331, y: 0.051105, width: 0.488950, height: 0.853591),
            CGRect(x: 0.261510, y: 0.022099, width: 0.500000, height: 0.882597)]
        case .comet: [CGRect(x: 0.337017, y: 0.034530, width: 0.325046, height: 0.935083),
            CGRect(x: 0.336096, y: 0.031768, width: 0.325967, height: 0.937845)]
        case .jun: [CGRect(x: 0.355433, y: 0.033149, width: 0.363720, height: 0.921271),
            CGRect(x: 0.356354, y: 0.033149, width: 0.362799, height: 0.921271)]
        case .luna: [CGRect(x: 0.334254, y: 0.027624, width: 0.358195, height: 0.928177),
            CGRect(x: 0.334254, y: 0.027624, width: 0.357274, height: 0.928177)]
        case .maple: [CGRect(x: 0.209024, y: 0.015193, width: 0.500921, height: 0.951657),
            CGRect(x: 0.208103, y: 0.015193, width: 0.501842, height: 0.950276)]
        case .mochi: [CGRect(x: 0.179558, y: 0.012431, width: 0.587477, height: 0.976519),
            CGRect(x: 0.179558, y: 0.008287, width: 0.587477, height: 0.980663)]
        case .nova: [CGRect(x: 0.331492, y: 0.024862, width: 0.449355, height: 0.941989),
            CGRect(x: 0.331492, y: 0.024862, width: 0.449355, height: 0.941989)]
        case .orbit: [CGRect(x: 0.328729, y: 0.030387, width: 0.348066, height: 0.908840),
            CGRect(x: 0.328729, y: 0.030387, width: 0.348987, height: 0.908840)]
        case .pebble: [CGRect(x: 0.291897, y: 0.040055, width: 0.517495, height: 0.925414),
            CGRect(x: 0.283610, y: 0.033149, width: 0.525783, height: 0.932320)]
        case .pip: [CGRect(x: 0.339779, y: 0.005525, width: 0.338858, height: 0.948895),
            CGRect(x: 0.341621, y: 0.012431, width: 0.336096, height: 0.941989)]
        case .wisp: [CGRect(x: 0.082031, y: 0.110352, width: 0.878906, height: 0.773438),
            CGRect(x: 0.050781, y: 0.063477, width: 0.882812, height: 0.820312)]
        }
    }
}

/// Separate calibration slots for the outer display and the open inner display.
enum DuoTuningLayout: String, Codable, CaseIterable {
    case frontPortrait = "duo-front-portrait"
    case frontLandscape = "duo-front-landscape"
    case unfoldedLandscape = "duo-unfolded-landscape"

    var title: String {
        switch self {
        case .frontPortrait: "Front portrait"
        case .frontLandscape: "Front landscape"
        case .unfoldedLandscape: "Unfolded landscape"
        }
    }

    static func resolve(size: CGSize, division: CGRect?) -> Self? {
        let visibleDivision = division.flatMap { rect -> CGRect? in
            rect.intersects(CGRect(origin: .zero, size: size)) ? rect : nil
        }
        if let visibleDivision, visibleDivision.width > visibleDivision.height { return nil }
        if size.width > size.height * 1.1 {
            return visibleDivision == nil ? .frontLandscape : .unfoldedLandscape
        }
        return .frontPortrait
    }
}

struct DuoFramingAdjustment: Codable, Equatable {
    var scaleMultiplier: Double = 1
    var offsetXFraction: Double = 0
    var offsetYFraction: Double = 0

    func apply(to frame: CGRect, seat: CGFloat, pane: CGSize) -> CGRect {
        let width = frame.width * scaleMultiplier
        let height = frame.height * scaleMultiplier
        return CGRect(x: frame.midX - width / 2 + offsetXFraction * pane.width,
                      y: frame.minY + frame.height * seat - height * seat + offsetYFraction * pane.height,
                      width: width, height: height)
    }
}

struct DuoFramingDraft: Codable {
    struct Entry: Codable {
        let companion: String
        let layout: DuoTuningLayout
        var scaleMultiplier: Double
        var offsetXFraction: Double
        var offsetYFraction: Double
        var adjustment: DuoFramingAdjustment {
            DuoFramingAdjustment(scaleMultiplier: scaleMultiplier,
                offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction)
        }
    }
    var version = 3
    var baseline = "Shared seated shelf geometry, November 12 2026"
    var units = "Scale multiplies the current fitted sprite around its seat. X and Y are fractions of the character pane width and height. Positive offsets move right/down. Backgrounds stay fixed."
    var entries: [Entry] = []

    func value(for companion: Companion, layout: DuoTuningLayout) -> DuoFramingAdjustment {
        entries.first { $0.companion == companion.rawValue && $0.layout == layout }?.adjustment ?? .init()
    }
    mutating func set(_ value: DuoFramingAdjustment, companion: Companion, layout: DuoTuningLayout) {
        entries.removeAll { $0.companion == companion.rawValue && $0.layout == layout }
        entries.append(Entry(companion: companion.rawValue, layout: layout,
            scaleMultiplier: value.scaleMultiplier, offsetXFraction: value.offsetXFraction,
            offsetYFraction: value.offsetYFraction))
    }
    func exportJSON() -> String {
        var complete = self
        complete.entries = DuoTuningLayout.allCases.flatMap { layout in
            Companion.allCases.map { companion in
                let value = value(for: companion, layout: layout)
                return Entry(companion: companion.rawValue, layout: layout,
                    scaleMultiplier: value.scaleMultiplier, offsetXFraction: value.offsetXFraction,
                    offsetYFraction: value.offsetYFraction)
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(decoding: encoder.encode(complete), as: UTF8.self)) ?? "{}"
    }
}
