import SwiftUI

/// The web timer's split-flap face, including the center seam and metal pivots.
struct FlipClock: View {
    let value: String
    let theme: CompanionTheme
    var maximumHeight: CGFloat = 96
    var body: some View {
        GeometryReader { proxy in
            let count = value.filter { $0 != ":" }.count
            let width = max(1, min(maximumHeight * 76 / 96,
                (proxy.size.width - CGFloat(count) * 6 - 18) / CGFloat(count)))
            let height = min(maximumHeight, width * 96 / 76)
            HStack(spacing: 6) {
                ForEach(Array(value.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        // Center the visible marks on the hinge, independent of
                        // the font's baseline and asymmetric glyph bearings.
                        VStack(spacing: height * 0.09) {
                            ForEach(0..<2) { _ in
                                RoundedRectangle(cornerRadius: height * 0.006)
                                    .fill(theme.clock.separator)
                                    .frame(width: height * 0.055, height: height * 0.065)
                            }
                        }.frame(width: 12, height: height)
                    } else {
                        FlipDigit(value: String(character), theme: theme)
                            .frame(width: width, height: height)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: maximumHeight)
        .accessibilityHidden(true)
    }
}

private struct FlipDigit: View {
    let value: String
    let theme: CompanionTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previous = ""
    @State private var outgoing = ""
    @State private var flipping = false
    @State private var flipProgress = 0.0
    private let flipDuration = 0.9

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Only the fixed housing casts a shadow. A shadow on the whole
                // stack can project the moving flap's edge across the numeral.
                RoundedRectangle(cornerRadius: 9).fill(theme.clock.base)
                    .shadow(color: theme.edge, radius: 0, y: 3)
                    .shadow(color: theme.clock.shadow, radius: 4.5, y: 5)
                VStack(spacing: 0) {
                    // Restore the printed seam only once the card has landed.
                    half(value, top: true, size: size, moving: flipping)
                    half(flipping ? outgoing : value, top: false, size: size, moving: flipping)
                }
                if flipping {
                    VStack(spacing: 0) {
                        half(outgoing, top: true, size: size, moving: true)
                            .modifier(FlapRotation(progress: flipProgress, top: true))
                        Color.clear.frame(height: size.height / 2)
                    }.drawingGroup().zIndex(1)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: size.height / 2)
                        half(value, top: false, size: size, moving: true)
                            .modifier(FlapRotation(progress: flipProgress, top: false))
                    }.drawingGroup().zIndex(2)
                }
                HStack {
                    pivot
                    Spacer()
                    pivot
                }.padding(.horizontal, -1).zIndex(3)
            }
        }
        .task(id: value) {
            let old = previous
            previous = value
            guard !old.isEmpty, old != value, !reduceMotion else { flipping = false; return }
            outgoing = old
            var reset = Transaction(); reset.disablesAnimations = true
            withTransaction(reset) {
                flipProgress = 0; flipping = true
            }
            // Both halves follow the same presentation progress; no sleep-driven
            // handoff can expose an edge-on face while the other half is moving.
            withAnimation(.linear(duration: flipDuration)) { flipProgress = 1 }
            do { try await Task.sleep(for: .seconds(flipDuration)) } catch { return }
            withTransaction(reset) { flipping = false }
        }
    }

    private var pivot: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(theme.hinge)
            .overlay {
                RoundedRectangle(cornerRadius: 1).fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.50), location: 0),
                    .init(color: .white.opacity(0.094), location: 0.38),
                    .init(color: .black.opacity(0.071), location: 0.65),
                    .init(color: .black.opacity(0.271), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .frame(width: 3, height: 7).shadow(color: .black.opacity(0.25), radius: 0.5, y: 1)
    }

    private func half(_ text: String, top: Bool, size: CGSize, moving: Bool = false) -> some View {
        LinearGradient(colors: top ? [theme.clock.topStart, theme.top] : [theme.clock.bottomStart, theme.bottom], startPoint: .top, endPoint: .bottom)
        .frame(width: size.width, height: size.height / 2)
        .overlay(alignment: top ? .top : .bottom) {
            // Match the web's 560px paper repeat and continuous top/bottom crop.
            // An overlay keeps this oversized decoration out of layout sizing.
            Image("paper-texture").resizable()
                .frame(width: 560, height: 560)
                .saturation(0).colorMultiply(Color(white: 0.55)).contrast(6)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped().opacity(0.14).blendMode(.luminosity)
        }
        .clipped()
        .compositingGroup()
        .overlay(alignment: .top) {
            if !moving { Rectangle().fill(.white.opacity(top ? 0.141 : 0.071)).frame(height: 1) }
        }
        .overlay(alignment: .bottom) {
            if top && !moving { Rectangle().fill(theme.clock.seam).frame(height: 1) }
        }
        .overlay(alignment: top ? .top : .bottom) {
            // Both flaps crop the same centered, full-height digit.
            Text(text)
                .font(.custom("Manrope-Bold", fixedSize: size.height * 0.75)).monospacedDigit()
                .foregroundStyle(theme.digit)
                .frame(width: size.width, height: size.height)
                .shadow(color: theme.clock.textShadow, radius: theme.clock.textShadowRadius, y: 1)
        }
        .clipped()
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: top ? 9 : 0, bottomLeadingRadius: top ? 0 : 9, bottomTrailingRadius: top ? 0 : 9, topTrailingRadius: top ? 9 : 0))
        // Rasterize the face and glyph together before applying perspective.
        .drawingGroup()
    }
}

/// Derive both phases and their visibility from one interpolated animation clock.
private struct FlapRotation: AnimatableModifier {
    var progress: Double
    let top: Bool
    var animatableData: Double { get { progress } set { progress = newValue } }

    func body(content: Content) -> some View {
        let phase = min(1, max(0, top ? progress * 2 : (progress - 0.5) * 2))
        let angle = top ? -90 * phase * phase : 90 * (1 - phase) * (1 - phase)
        let active = top ? progress < 0.5 : progress >= 0.5
        let visible = active && abs(angle) < 89.5
        content
            // An exactly edge-on projection is singular even at zero opacity.
            // Hidden faces use an identity transform instead of a degenerate one.
            .rotation3DEffect(.degrees(visible ? angle : 0), axis: (x: 1, y: 0, z: 0),
                              anchor: top ? .bottom : .top, perspective: 0.35)
            .opacity(visible ? 1 : 0)
    }
}
