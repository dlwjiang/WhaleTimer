import SwiftUI

struct CompanionSpeech: Identifiable {
    let id: Int
    let text: String
    let cue: String
    let speaker: Companion
}

/// Outlined speech floats beside the mouth, in the same transformed space as the sprite.
/// The audio service owns expiration; removing a caption leaves no subtitle/name panel.
struct AvatarSpeechOverlay: View {
    let speech: CompanionSpeech?
    let companion: Companion
    let pose: String
    var sceneMouth: CGPoint? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        MouthSpeechLayout(mouth: companion.mouthAnchor(pose: pose), expanded: dynamicTypeSize.isAccessibilitySize,
                          sceneMouth: sceneMouth) {
            if let speech {
                FloatingSpeechText(speech: speech, color: CompanionTheme(companion).accent)
                    .id(speech.id)
                    .transition(.asymmetric(insertion: .opacity,
                        removal: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -10))))
            }
        }
        .animation(.easeOut(duration: 0.18), value: speech?.id)
        .allowsHitTesting(false)
        .accessibilityHidden(true) // The avatar exposes the complete phrase to VoiceOver.
    }
}

private struct FloatingSpeechText: View {
    let speech: CompanionSpeech
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var phraseSize: CGFloat = 25
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 62
    @State private var entered = false

    private var fontSize: CGFloat {
        Int(speech.cue) != nil ? numberSize : speech.cue == "go" ? phraseSize * 1.28 : phraseSize
    }
    var body: some View {
        Text(verbatim: speech.text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            // Hard cream outline and colored drop shadow, matching the web's unboxed lettering.
            .shadow(color: Palette.paper, radius: 0, x: -2, y: 0)
            .shadow(color: Palette.paper, radius: 0, x: 2, y: 0)
            .shadow(color: Palette.paper, radius: 0, x: 0, y: -2)
            .shadow(color: Palette.paper, radius: 0, x: 0, y: 2)
            .shadow(color: color.opacity(0.3), radius: 0, x: 0, y: 3)
            .shadow(color: Palette.ink.opacity(0.12), radius: 5, x: 0, y: 5)
            .scaleEffect(entered || reduceMotion ? 1 : 0.55, anchor: .topLeading)
            .rotationEffect(.degrees(entered || reduceMotion ? 0 : -8), anchor: .topLeading)
            .offset(x: entered || reduceMotion ? 0 : -7, y: entered || reduceMotion ? 0 : 10)
            .opacity(entered ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(duration: 0.5, bounce: 0.35)) {
                    entered = true
                }
            }
            .accessibilityIdentifier("companion-floating-speech")
    }
}

/// Measure wrapping text before placement, without writing layout measurements into view state.
/// At accessibility sizes the phrase can use the full scene width, still originating near the face.
private struct MouthSpeechLayout: Layout {
    let mouth: CGPoint
    let expanded: Bool
    var sceneMouth: CGPoint? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = min(bounds.width, bounds.height)
        let mouthX = sceneMouth.map { bounds.width * $0.x } ?? ((bounds.width - size) / 2 + size * mouth.x)
        let mouthY = sceneMouth.map { bounds.height * $0.y } ?? ((bounds.height - size) / 2 + size * mouth.y)
        let desiredX = mouthX + size * 0.055 - 20
        let x = expanded ? 12 : max(12, min(desiredX, bounds.width - 158))
        let width = max(1, min(expanded ? bounds.width - 24 : 224, bounds.width - x - 12))
        for view in subviews {
            let measured = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let y = max(12, min(mouthY + 8, bounds.height - measured.height - 12))
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), anchor: .topLeading,
                       proposal: ProposedViewSize(width: width, height: measured.height))
        }
    }
}

private extension Companion {
    /// Normalized mouth positions in the extracted square art: idle, focus, rest, happy.
    func mouthAnchor(pose: String) -> CGPoint {
        let anchors: [CGPoint]
        switch self {
        case .pebble: anchors = [.init(x: 0.43, y: 0.41), .init(x: 0.43, y: 0.48), .init(x: 0.40, y: 0.63), .init(x: 0.48, y: 0.39)]
        case .maple: anchors = [.init(x: 0.60, y: 0.38), .init(x: 0.57, y: 0.48), .init(x: 0.58, y: 0.45), .init(x: 0.55, y: 0.37)]
        case .wisp: anchors = [.init(x: 0.58, y: 0.45), .init(x: 0.55, y: 0.48), .init(x: 0.47, y: 0.53), .init(x: 0.54, y: 0.37)]
        case .comet: anchors = [.init(x: 0.52, y: 0.47), .init(x: 0.51, y: 0.55), .init(x: 0.54, y: 0.52), .init(x: 0.53, y: 0.46)]
        case .mochi: anchors = [.init(x: 0.59, y: 0.45), .init(x: 0.51, y: 0.60), .init(x: 0.36, y: 0.68), .init(x: 0.55, y: 0.40)]
        case .pip: anchors = [.init(x: 0.58, y: 0.44), .init(x: 0.57, y: 0.47), .init(x: 0.58, y: 0.44), .init(x: 0.58, y: 0.42)]
        case .jun: anchors = [.init(x: 0.52, y: 0.35), .init(x: 0.49, y: 0.38), .init(x: 0.50, y: 0.38), .init(x: 0.47, y: 0.35)]
        case .bean: anchors = [.init(x: 0.66, y: 0.43), .init(x: 0.65, y: 0.62), .init(x: 0.38, y: 0.66), .init(x: 0.56, y: 0.44)]
        case .luna: anchors = [.init(x: 0.56, y: 0.35), .init(x: 0.56, y: 0.40), .init(x: 0.57, y: 0.36), .init(x: 0.54, y: 0.34)]
        case .atlas: anchors = [.init(x: 0.63, y: 0.40), .init(x: 0.63, y: 0.57), .init(x: 0.60, y: 0.55), .init(x: 0.58, y: 0.43)]
        case .nova: anchors = [.init(x: 0.52, y: 0.35), .init(x: 0.53, y: 0.39), .init(x: 0.51, y: 0.40), .init(x: 0.51, y: 0.34)]
        case .orbit: anchors = [.init(x: 0.58, y: 0.54), .init(x: 0.55, y: 0.58), .init(x: 0.56, y: 0.58), .init(x: 0.54, y: 0.47)]
        }
        return anchors[["idle", "focus", "rest", "happy"].firstIndex(of: pose) ?? 0]
    }
}
