import SwiftUI
import Combine

struct StudyView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settingsPresented = false
    @State private var companionsPresented = false
    @State private var openness = 1.0
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var theme: CompanionTheme { CompanionTheme(store.companion) }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Group {
                    if #available(iOS 27.1, *), !proxy.reservedRegions(kind: .division).isEmpty {
                        ArrangementView {
                            GeometryReader { region in
                                ScrollView {
                                    CompanionScene(openness: openness,
                                        sceneHeight: max(180, region.size.height - 12))
                                }
                            }
                        } secondary: {
                            ScrollView {
                                TimerPanel(compact: true).padding(20)
                                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
                            }
                        }
                        .arrangementViewStyle(.split)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                CompanionScene(openness: openness,
                                    sceneHeight: max(230, min(560, proxy.size.height - 298)))
                                    .frame(maxWidth: 760)
                                TimerPanel(compact: proxy.size.width < 740)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: 592)
                                Button("Meet more companions", systemImage: "sparkles") { companionsPresented = true }
                                    .font(.subheadline).foregroundStyle(theme.accent).padding(.top, 16)
                                    .frame(minHeight: 44)
                                Text("A little company. One thing at a time.")
                                    .font(.caption2).foregroundStyle(Palette.ink.opacity(0.5))
                                    .padding(.vertical, 16)
                            }.frame(maxWidth: .infinity)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
                .background {
                    Image("paper-texture").resizable().scaledToFill()
                        .overlay(theme.soft.opacity(0.25))
                        .accessibilityHidden(true)
                        .ignoresSafeArea()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $settingsPresented) { SettingsView().tint(theme.accent) }
            .sheet(isPresented: $companionsPresented) { CompanionShopView() }
            .modifier(HingeLight(openness: $openness, reduceMotion: reduceMotion))
            .background(Palette.paper.ignoresSafeArea())
        }
        .preferredColorScheme(.light)
        .onReceive(ticker) { now in
            if scenePhase == .active { store.tick(now: now) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.foreground(); Task { await purchases.refreshEntitlements() } }
            else { store.background() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("brand-hourglass").resizable().scaledToFit().frame(width: 34, height: 38)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("app.name").font(.system(.title2, weight: .semibold))
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .foregroundStyle(Color(hex: 0x59618e))
                    .accessibilityIdentifier("app-title")
                Text("YOUR FOCUS COMPANION").font(.system(size: 8, weight: .medium))
                    .tracking(0.8).foregroundStyle(Color(hex: 0x6d6987))
            }
            Spacer(minLength: 4)
            headerButton(store.state.settings.soundEnabled ? "speaker.wave.2" : "speaker.slash", label: L10n.text(store.state.settings.soundEnabled ? "Mute sounds" : "Enable sounds")) {
                var settings = store.state.settings
                settings.soundEnabled.toggle()
                store.updateSettings(settings)
            }
            headerButton("gearshape", label: L10n.text("Timer settings")) { settingsPresented = true }
        }
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
        .modifier(GlassSurface(tint: theme.soft, radius: 22))
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 8)
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity)
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17))
                .frame(width: 44, height: 44)
                .foregroundStyle(theme.accent)
                .background(.white.opacity(0.22), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.7)))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

private struct HingeLight: ViewModifier {
    @Binding var openness: Double
    var reduceMotion: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange(isEnabled: !reduceMotion) { _, context in
                openness = context.hinge.map { min(1, max(0, $0.angle.degrees / 180)) } ?? 1
            }
        } else { content }
    }
}

struct TimerPanel: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var theme: CompanionTheme { CompanionTheme(store.companion) }
    var compact = false

    private var clock: String {
        let seconds = Int(ceil(store.session.remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    private var buttonTitle: String {
        switch store.session.status {
        case .ready: L10n.text(store.session.phase == .focus ? "Start focusing" : "Start break")
        case .running, .preparing: L10n.text("Pause")
        case .paused, .preparationPaused: L10n.text("Keep going")
        case .complete: L10n.text(store.state.nextPhase == .focus ? "Start next focus" : store.state.nextPhase == .shortBreak ? "Start short break" : "Start long break")
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(store.session.phase.title.uppercased())
                    .font(.system(.caption2, weight: .semibold)).tracking(1.8)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<4) { index in
                        Circle().fill(index < store.state.completedInCycle ? theme.accent : theme.accent.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text("%lld of 4 focus sessions complete", store.state.completedInCycle))
            }.foregroundStyle(theme.accent)

            FlipClock(value: clock, theme: theme)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(remainingDescription)
                .accessibilityHidden(false)
            ProgressView(value: store.session.progress).tint(theme.accent)
                .accessibilityLabel("Session progress")

            let actions = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            actions {
                Button { store.primaryAction() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: [SessionStatus.running, .preparing].contains(store.session.status) ? "pause.fill" : "play.fill")
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                        Text(buttonTitle).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(GlassKey(theme: theme, engaged: [SessionStatus.running, .preparing].contains(store.session.status)))
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityIdentifier("timer-primary")

                SlideToReset(theme: theme) { store.reset() }
            }

            if store.session.phase != .focus {
                Button("Back to focus") { store.skipBreak() }
                    .font(.caption).foregroundStyle(theme.accent).frame(minHeight: 32)
            }
            if let message = store.notificationMessage ?? store.storageMessage {
                Text(L10n.text(message)).font(.footnote).foregroundStyle(Palette.clay).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, compact ? 20 : 28).padding(.top, 24).padding(.bottom, 8)
        .foregroundStyle(Palette.ink)
        .modifier(GlassSurface(tint: theme.soft, radius: 28))

    }

    private var remainingDescription: String {
        let value = Int(ceil(store.session.remaining))
        return L10n.text("Remaining: %lld:%02lld", value / 60, value % 60)
    }
}

