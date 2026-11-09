import SwiftUI

/// The web timer's split-flap face, including the center seam and metal pivots.
struct FlipClock: View {
    let value: String
    let theme: CompanionTheme
    var body: some View {
        GeometryReader { proxy in
            let count = value.filter { $0 != ":" }.count
            let width = min(76, (proxy.size.width - CGFloat(count) * 6 - 18) / CGFloat(count))
            let height = min(96, width * 96 / 76)
            let fontSize = height * 0.75
            HStack(spacing: 6) {
                ForEach(Array(value.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        Text(verbatim: ":").font(.custom("Manrope-Bold", fixedSize: fontSize * 0.65))
                            .foregroundStyle(theme.clock.separator).frame(width: 12)
                    } else {
                        FlipDigit(value: String(character), theme: theme)
                            .frame(width: width, height: height)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 96)
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
    @State private var landing = false
    @State private var upperAngle = 0.0
    @State private var lowerAngle = 90.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                VStack(spacing: 0) {
                    half(value, top: true, size: size)
                    half(flipping ? outgoing : value, top: false, size: size)
                }
                if flipping {
                    VStack(spacing: 0) {
                        half(outgoing, top: true, size: size, moving: true)
                            .modifier(FlapRotation(angle: upperAngle, anchor: .bottom))
                        Color.clear.frame(height: size.height / 2)
                    }.opacity(landing ? 0 : 1).zIndex(1)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: size.height / 2)
                        half(value, top: false, size: size, moving: true)
                            .modifier(FlapRotation(angle: lowerAngle, anchor: .top))
                    }.opacity(landing ? 1 : 0).zIndex(2)
                }
                HStack {
                    pivot
                    Spacer()
                    pivot
                }.padding(.horizontal, -1).zIndex(3)
            }
            .background(theme.clock.base, in: RoundedRectangle(cornerRadius: 9))
            .shadow(color: theme.edge, radius: 0, y: 3)
            .shadow(color: theme.clock.shadow, radius: 4.5, y: 5)
        }
        .task(id: value) {
            let old = previous
            previous = value
            guard !old.isEmpty, old != value, !reduceMotion else { flipping = false; return }
            outgoing = old
            var reset = Transaction(); reset.disablesAnimations = true
            withTransaction(reset) {
                upperAngle = 0; lowerAngle = 90; landing = false; flipping = true
            }
            withAnimation(.easeIn(duration: 0.24)) { upperAngle = -90 }
            do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
            // Never leave an edge-on card in front of the other card's numeral.
            withTransaction(reset) { landing = true }
            withAnimation(.easeOut(duration: 0.28)) { lowerAngle = 0 }
            do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
            flipping = false
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
        // Rotate one composed surface so highlights cannot sort above its glyph.
        .compositingGroup()
    }
}

/// Evaluate visibility at the interpolated angle, not just the animation endpoints.
/// A flattened, edge-on face would otherwise rasterize as a bar across the hinge.
private struct FlapRotation: AnimatableModifier {
    var angle: Double
    let anchor: UnitPoint
    var animatableData: Double { get { angle } set { angle = newValue } }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: anchor, perspective: 0.35)
            .opacity(abs(angle) >= 89.5 ? 0 : 1)
    }
}
