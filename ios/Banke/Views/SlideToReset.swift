import SwiftUI

/// Drag from the handle; releasing before 88% springs back without changing the timer.
struct SlideToReset: View {
    let theme: CompanionTheme
    var compact = false
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption) private var controlHeight: CGFloat = 60
    @GestureState private var translation: CGFloat = 0
    @State private var confirmAccessibleReset = false

    var body: some View {
        GeometryReader { proxy in
            let travel = max(0, proxy.size.width - 60)
            let fraction = InteractionGeometry.resetFraction(translation: translation, travel: travel)
            ZStack(alignment: .leading) {
                Text(compact ? LocalizedStringKey("Start over") : LocalizedStringKey("Slide to start over"))
                    .font(.system(.caption, weight: .semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : compact ? 1 : 2)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                    .multilineTextAlignment(.center).padding(.leading, 56).padding(.trailing, 10)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(theme.accent.opacity(1 - fraction))
                RoundedRectangle(cornerRadius: 15)
                    .fill(theme.accent.opacity(0.12)).frame(width: 48 + travel * fraction)
                    .padding(6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 48, height: 48)
                    .modifier(GlassSurface(tint: theme.soft, radius: 15))
                    .contentShape(RoundedRectangle(cornerRadius: 15))
                    .offset(x: 6 + travel * fraction)
                    .gesture(DragGesture(minimumDistance: 3)
                        .updating($translation) { value, state, _ in
                            guard scenePhase == .active, abs(value.translation.width) > abs(value.translation.height) else { return }
                            state = value.translation.width
                        }
                        .onEnded { value in
                            guard scenePhase == .active, abs(value.translation.width) > abs(value.translation.height) else { return }
                            let progress = InteractionGeometry.resetFraction(translation: value.translation.width, travel: travel)
                            if InteractionGeometry.shouldReset(fraction: progress) { action() }
                        })
            }
            .modifier(GlassSurface(tint: theme.soft, radius: 18))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: translation == 0)
        }
        .frame(minWidth: 130, minHeight: controlHeight, maxHeight: controlHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Start over")
        .accessibilityHint("Activate to confirm a fresh focus session. You can also drag the handle to the right.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmAccessibleReset = true }
        .focusable()
        .onKeyPress(.return) { confirmAccessibleReset = true; return .handled }
        .onKeyPress(.space) { confirmAccessibleReset = true; return .handled }
        .confirmationDialog("Start a fresh focus session?", isPresented: $confirmAccessibleReset, titleVisibility: .visible) {
            Button("Start over", role: .destructive, action: action)
            Button("Cancel", role: .cancel) { }
        }
        .accessibilityIdentifier("timer-reset-slider")
    }
}
