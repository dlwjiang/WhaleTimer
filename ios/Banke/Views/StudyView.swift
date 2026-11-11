import SwiftUI
import Combine

struct StudyView: View {
    #if DEBUG
    var previewTabletop = ProcessInfo.processInfo.arguments.contains("-preview-tabletop")
    #else
    private let previewTabletop = false
    #endif
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var headerTextSize
    @State private var settingsPresented = false
    @State private var openness = 1.0
    @State private var tabletopHeaderHeight: CGFloat = 56
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var theme: CompanionTheme { CompanionTheme(store.companion) }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Group {
                    if usesDuoCanvas(proxy) || previewTabletop || (proxy.size.width > proxy.size.height * 1.15 && proxy.size.height < 620) {
                        adaptiveCanvas(proxy)
                    } else {
                        GeometryReader { contentRegion in
                            ScrollView {
                                VStack(spacing: 0) {
                                    CompanionScene(openness: openness,
                                        sceneHeight: max(230, min(560, contentRegion.size.height - 298)))
                                        .frame(maxWidth: 760)
                                    TimerPanel(compact: proxy.size.width < 740)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: 592)
                                    Text("A little company. One thing at a time.")
                                        .font(.caption2).foregroundStyle(Palette.ink.opacity(0.5))
                                        .padding(.vertical, 16)
                                }.frame(maxWidth: .infinity)
                            }
                            .scrollIndicators(.hidden)
                        }
                        .safeAreaInset(edge: .top, spacing: 0) { header }
                    }
                }
                .background {
                    Image("paper-texture").resizable().scaledToFill()
                        .overlay(theme.soft.opacity(0.25))
                        .accessibilityHidden(true)
                        .ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $settingsPresented) { SettingsView().tint(theme.accent) }
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

    private func usesDuoCanvas(_ proxy: GeometryProxy) -> Bool {
        if #available(iOS 27.1, *) {
            return !proxy.reservedRegions(kind: .division, options: .includeInactive).isEmpty
                || proxy.safeAreaInsets.trailing >= 80 || proxy.safeAreaInsets.leading >= 80
                || proxy.reservedRegions(kind: .occlusion).contains {
                    $0.frame.midX > proxy.size.width * 0.6 && $0.frame.width >= 80 && $0.frame.height >= 80
                }
        }
        return false
    }

    /// One full-screen coordinate space for every Duo posture. The old routes
    /// mixed a safe-area-sized canvas, a top-only offset and a separate header
    /// inset, which broke whenever the status rail moved to the right edge.
    private func adaptiveCanvas(_ proxy: GeometryProxy) -> some View {
        let safe = proxy.safeAreaInsets
        let size = CGSize(width: proxy.size.width + safe.leading + safe.trailing,
                          height: proxy.size.height + safe.top + safe.bottom)
        return GeometryReader { canvas in
            let division = canvasDivision(canvas)
            let occlusions = canvasOcclusions(canvas)
            let placement = TabletopHeaderLayout(width: size.width, topInset: safe.top,
                headerHeight: tabletopHeaderHeight, occlusions: occlusions, division: division,
                allowsInline: !headerTextSize.isAccessibilitySize)
            let controlsBottom = occlusions.filter { $0.minY >= -1 && $0.maxY <= 210 }.map(\.maxY).max() ?? safe.top
            let contentTop = max(placement.frame.maxY + 12, controlsBottom)
            let contentBottom = size.height - safe.bottom - 12
            ZStack(alignment: .topLeading) {
                if let division, division.width > division.height {
                    tabletop(size: size, division: division, bottomInset: safe.bottom)
                } else if size.width > size.height * 1.1 {
                    sideBySide(size: size, division: division, top: contentTop, bottom: contentBottom)
                } else {
                    singleColumn(size: size, top: contentTop, bottom: contentBottom)
                }
                headerContent(compactHeight: headerTextSize.isAccessibilitySize ? nil : placement.frame.height)
                    .frame(width: placement.frame.width)
                    .background {
                        GeometryReader { measurement in
                            Color.clear.preference(key: TabletopHeaderHeight.self, value: measurement.size.height)
                        }
                    }
                    .offset(x: placement.frame.minX, y: placement.frame.minY)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height)
        .onPreferenceChange(TabletopHeaderHeight.self) { tabletopHeaderHeight = $0 }
        .offset(x: -safe.leading, y: -safe.top)
    }

    private func canvasDivision(_ proxy: GeometryProxy) -> CGRect? {
        if previewTabletop {
            return CGRect(x: 0, y: proxy.size.height * 0.46, width: proxy.size.width, height: 16)
        }
        // Keep the same room, seated artwork and panel split when the hinge
        // opens flat; its inactive division still describes the physical fold.
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division, options: .includeInactive).first?.frame
        }
        return nil
    }

    private func canvasOcclusions(_ proxy: GeometryProxy) -> [CGRect] {
        if #available(iOS 27.1, *) { return proxy.reservedRegions(kind: .occlusion).map(\.frame) }
        return []
    }

    private func tabletop(size: CGSize, division: CGRect, bottomInset: CGFloat) -> some View {
        let layout = TabletopSceneLayout(size: CGSize(width: size.width, height: size.height - bottomInset),
                                        division: division)
        return ZStack(alignment: .top) {
            CompanionScene(compact: true, openness: openness,
                sceneHeight: layout.sceneHeight, tabletopHingeY: layout.hingeY)
            ScrollView {
                TimerPanel(compact: true, clockHeight: layout.clockHeight(width: size.width))
                    .frame(maxWidth: 900)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
            .frame(height: layout.timerHeight)
            .padding(.top, layout.timerTop)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
    }

    private func sideBySide(size: CGSize, division: CGRect?, top: CGFloat, bottom: CGFloat) -> some View {
        let split = division ?? CGRect(x: size.width * 0.43, y: 0, width: 8, height: size.height)
        let height = max(0, bottom - top)
        let timerWidth = max(0, size.width - split.maxX)
        return HStack(spacing: 0) {
            CompanionScene(compact: true, openness: openness, sceneHeight: height, showsSelector: false)
                .frame(width: max(0, split.minX), height: height)
            Color.clear.frame(width: max(0, split.width), height: height)
            ScrollView {
                TimerPanel(compact: true, clockHeight: min(180, max(76, (timerWidth - 82) * 96 / 304)), dense: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: height)
            }
            .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
            .frame(width: timerWidth, height: height)
        }
        .frame(width: size.width, height: height, alignment: .top)
        .offset(y: top)
    }

    private func singleColumn(size: CGSize, top: CGFloat, bottom: CGFloat) -> some View {
        let height = max(0, bottom - top)
        let dense = size.width < 600
        let clockHeight = min(dense ? 112.0 : 160.0, max(76, (size.width - 110) * 96 / 304))
        let companionHeight = max(140, min(450, height - clockHeight - (dense ? 156 : 184)))
        return ScrollView {
            VStack(spacing: 8) {
                CompanionScene(compact: true, openness: openness, sceneHeight: companionHeight, showsSelector: false)
                    .frame(maxWidth: 760)
                TimerPanel(compact: true, clockHeight: clockHeight, dense: dense)
                    .frame(maxWidth: 700)
                    .padding(.horizontal, 16)
            }.frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        .frame(width: size.width, height: height)
        .offset(y: top)
    }

    private var header: some View {
        headerContent()
            .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 8)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
    }

    private func headerContent(compactHeight: CGFloat? = nil) -> some View {
        HStack(spacing: 8) {
            Image("brand-hourglass").resizable().scaledToFit().frame(width: compactHeight == nil ? 34 : 28, height: compactHeight == nil ? 38 : 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: compactHeight == nil ? 4 : 1) {
                Text("app.name").font(compactHeight == nil ? .system(.title2, weight: .semibold) : .system(size: 20, weight: .semibold))
                    .lineLimit(compactHeight == nil ? 2 : 1).minimumScaleFactor(0.8)
                    .foregroundStyle(Color(hex: 0x59618e))
                    .accessibilityIdentifier("app-title")
                Text(store.companion.name).font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(Color(hex: 0x6d6987))
                    .accessibilityIdentifier("active-companion-name")
            }
            Spacer(minLength: 4)
            headerButton(store.state.settings.soundEnabled ? "speaker.wave.2" : "speaker.slash", label: L10n.text(store.state.settings.soundEnabled ? "Mute sounds" : "Enable sounds")) {
                var settings = store.state.settings
                settings.soundEnabled.toggle()
                store.updateSettings(settings)
            }
            headerButton("gearshape", label: L10n.text("Timer settings")) { settingsPresented = true }
        }
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, compactHeight == nil ? 6 : 0)
        .frame(height: compactHeight)
        .modifier(GlassSurface(tint: theme.soft, radius: 22, native: true))
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

private struct TabletopHeaderHeight: PreferenceKey {
    static let defaultValue: CGFloat = 56
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
    var clockHeight: CGFloat = 96
    var dense = false

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
        VStack(spacing: dense ? 10 : 14) {
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

            FlipClock(value: clock, theme: theme, maximumHeight: clockHeight)
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
        .padding(.horizontal, dense ? 16 : compact ? 20 : 28).padding(.top, dense ? 14 : 24).padding(.bottom, 8)
        .foregroundStyle(Palette.ink)
        .modifier(GlassSurface(tint: theme.soft, radius: 28, native: true))

    }

    private var remainingDescription: String {
        let value = Int(ceil(store.session.remaining))
        return L10n.text("Remaining: %lld:%02lld", value / 60, value % 60)
    }
}

