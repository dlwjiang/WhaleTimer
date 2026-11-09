import Foundation

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
