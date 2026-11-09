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
                        half(outgoing, top: true, size: size)
                            .rotation3DEffect(.degrees(upperAngle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.35)
                        Color.clear.frame(height: size.height / 2)
                    }
                    VStack(spacing: 0) {
                        Color.clear.frame(height: size.height / 2)
                        half(value, top: false, size: size)
                            .rotation3DEffect(.degrees(lowerAngle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.35)
                    }
                }
                HStack {
                    pivot
                    Spacer()
                    pivot
                }.padding(.horizontal, -1)
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
            upperAngle = 0; lowerAngle = 90; flipping = true
            withAnimation(.easeIn(duration: 0.24)) { upperAngle = -90 }
            do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
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

    private func half(_ text: String, top: Bool, size: CGSize) -> some View {
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
            Rectangle().fill(.white.opacity(top ? 0.141 : 0.071)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            if top { Rectangle().fill(theme.clock.seam).frame(height: 1) }
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
    }
}
