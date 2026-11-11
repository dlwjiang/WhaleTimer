import Foundation
import CoreGraphics

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
                // The bottom 124 points contain the clock and connectivity
                // controls; a closed device may reserve camera space above.
                centerY = statusArea.maxY - min(62, statusArea.height / 2)
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
