import SwiftUI
import Combine

struct StudyView: View {
    #if DEBUG
    @AppStorage("duo-shelf-framing-v3") private var framingJSON = ""
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
    @State private var deviceHeaderHeight: CGFloat = 72
    @ScaledMetric(relativeTo: .subheadline) private var deviceNameHeight: CGFloat = 44
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var theme: CompanionTheme { CompanionTheme(store.companion) }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Group {
                    if usesDuoCanvas(proxy) || previewTabletop {
                        adaptiveCanvas(proxy)
                    } else {
                        deviceCanvas(proxy)
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

    /// Phone and iPad rooms are composed for their actual window shape. Their
    /// seat landmark and the live sprite share the same full-screen coordinates.
    private func deviceCanvas(_ proxy: GeometryProxy) -> some View {
        let safe = proxy.safeAreaInsets
        let size = CGSize(width: proxy.size.width + safe.leading + safe.trailing,
                          height: proxy.size.height + safe.top + safe.bottom)
        let format = DeviceRoomFormat.resolve(size: size, isPad: UIDevice.current.userInterfaceIdiom == .pad)
        let landscape = format.isLandscape
        let top = safe.top + deviceHeaderHeight + 12
        let bottom = size.height - safe.bottom - 12
        let floorY = max(top + 100, size.height * (landscape ? 0.77 : 0.54))
        let ledgeY = max(top + 72, size.height * (landscape ? 0.65 : 0.46))
        let feetY = floorY + min(20, size.height * 0.025)
        let showName = UIDevice.current.userInterfaceIdiom == .pad
        let selectorSpace: CGFloat = showName ? deviceNameHeight + 24 : 24
        let sceneHeight = max(160, feetY - top + selectorSpace + 12)
        return ZStack(alignment: .topLeading) {
            ZStack {
                DeviceRoomBackdrop(room: store.companion.duoRoom, format: format, size: size, ledgeY: ledgeY,
                    characterX: landscape ? safe.leading + (size.width - safe.leading - safe.trailing) * 0.23 : size.width / 2)
                    .id("\(format.rawValue)-\(store.companion.duoRoom.rawValue)")
                    .transition(.opacity)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: store.companion.duoRoom)
            .allowsHitTesting(false).accessibilityHidden(true)
            if landscape {
                let contentWidth = max(0, size.width - safe.leading - safe.trailing)
                let characterWidth = contentWidth * 0.46
                let availableHeight = max(120, bottom - top)
                HStack(spacing: 0) {
                    CompanionScene(compact: true, openness: openness, sceneHeight: availableHeight,
                        showsSelector: false, showsBackdrop: false, roomLedgeY: ledgeY - top)
                        .frame(width: characterWidth, height: availableHeight)
                    ScrollView {
                        TimerPanel(compact: true,
                            clockHeight: min(160, max(70, (contentWidth - characterWidth - 82) * 96 / 304)),
                            dense: size.height < 600)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: availableHeight)
                    }
                    .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
                }
                .frame(width: contentWidth, height: availableHeight)
                .offset(x: safe.leading, y: top)
            } else {
                // Keep the seat attached to its painted ledge while the timer scrolls.
                VStack(spacing: 8) {
                    CompanionScene(openness: openness, sceneHeight: sceneHeight,
                        showsName: showName, showsBackdrop: false, roomLedgeY: ledgeY - top)
                        .frame(maxWidth: 760).frame(height: sceneHeight)
                    ScrollView {
                        TimerPanel(compact: size.width < 740,
                            clockHeight: size.width < 600 ? 96 : 156)
                            .padding(.horizontal, 16).frame(maxWidth: 720)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
                }
                .frame(width: proxy.size.width, height: max(0, bottom - top), alignment: .top)
                .offset(x: safe.leading, y: top)
            }

            headerContent()
                .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 8)
                .frame(width: proxy.size.width)
                .background {
                    GeometryReader { measurement in
                        Color.clear.preference(key: DeviceHeaderHeight.self, value: measurement.size.height)
                    }
                }
                .offset(x: safe.leading, y: safe.top)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .onPreferenceChange(DeviceHeaderHeight.self) { deviceHeaderHeight = $0 }
        .offset(x: -safe.leading, y: -safe.top)
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
            let tuningLayout = DuoTuningLayout.resolve(size: size, division: division)
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
                    sideBySide(size: size, division: division, top: contentTop, bottom: contentBottom, tuningLayout: tuningLayout)
                } else {
                    singleColumn(size: size, top: contentTop, bottom: contentBottom, tuningLayout: tuningLayout)
                }
                headerContent(compactHeight: headerTextSize.isAccessibilitySize ? nil : placement.frame.height)
                    .frame(width: placement.frame.width)
                    .background {
                        GeometryReader { measurement in
                            Color.clear.preference(key: TabletopHeaderHeight.self, value: measurement.size.height)
                        }
                    }
                    .offset(x: placement.frame.minX, y: placement.frame.minY)
                #if DEBUG
                if let tuningLayout {
                    DuoFramingPanel(companion: store.companion, layout: tuningLayout,
                        value: framingBinding(layout: tuningLayout), exportJSON: framingDraft.exportJSON())
                        .frame(width: min(350, size.width - 32))
                        .padding(.leading, 16).padding(.bottom, safe.bottom + 12)
                        .frame(width: size.width, height: size.height, alignment: .bottomLeading)
                }
                #endif
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

    private func sideBySide(size: CGSize, division: CGRect?, top: CGFloat, bottom: CGFloat, tuningLayout: DuoTuningLayout?) -> some View {
        let split = division ?? CGRect(x: size.width * 0.43, y: 0, width: 8, height: size.height)
        let height = max(0, bottom - top)
        let timerWidth = max(0, size.width - split.maxX)
        let ledgeY = height * 0.65
        return HStack(spacing: 0) {
            CompanionScene(compact: true, openness: openness, sceneHeight: height,
                           showsSelector: false, showsBackdrop: false, roomLedgeY: ledgeY,
                           framingAdjustments: adjustments(layout: tuningLayout))
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
        .background(alignment: .topLeading) {
            shelfRoom(size: size, ledgeY: top + ledgeY, characterX: split.minX / 2)
        }
    }

    private func singleColumn(size: CGSize, top: CGFloat, bottom: CGFloat, tuningLayout: DuoTuningLayout?) -> some View {
        let height = max(0, bottom - top)
        let dense = size.width < 600
        let clockHeight = min(dense ? 112.0 : 160.0, max(76, (size.width - 110) * 96 / 304))
        let companionHeight = max(140, min(450, height - clockHeight - (dense ? 156 : 184)))
        let ledgeY = companionHeight * 0.70
        return VStack(spacing: 8) {
            CompanionScene(compact: true, openness: openness, sceneHeight: companionHeight,
                showsSelector: false, showsBackdrop: false, roomLedgeY: ledgeY,
                framingAdjustments: adjustments(layout: tuningLayout))
                .frame(maxWidth: 760).frame(height: companionHeight)
            ScrollView {
                TimerPanel(compact: true, clockHeight: clockHeight, dense: dense)
                    .frame(maxWidth: 700).padding(.horizontal, 16)
                    .frame(maxWidth: .infinity).padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        }
        .frame(width: size.width, height: height, alignment: .top)
        .offset(y: top)
        .background(alignment: .topLeading) {
            shelfRoom(size: size, ledgeY: top + ledgeY, characterX: size.width / 2)
        }
    }

    private func shelfRoom(size: CGSize, ledgeY: CGFloat, characterX: CGFloat) -> some View {
        ZStack {
            DeviceRoomBackdrop(room: store.companion.duoRoom,
                format: DeviceRoomFormat.resolve(size: size, isPad: false),
                size: size, ledgeY: ledgeY, characterX: characterX)
                .id(store.companion.duoRoom).transition(.opacity)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: store.companion.duoRoom)
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func adjustments(layout: DuoTuningLayout?) -> [Companion: DuoFramingAdjustment] {
        #if DEBUG
        guard let layout else { return [:] }
        let draft = framingDraft
        return Dictionary(uniqueKeysWithValues: Companion.allCases.map { ($0, draft.value(for: $0, layout: layout)) })
        #else
        return [:]
        #endif
    }

    #if DEBUG
    private var framingDraft: DuoFramingDraft {
        (try? JSONDecoder().decode(DuoFramingDraft.self, from: Data(framingJSON.utf8))) ?? .init()
    }
    private func framingBinding(layout: DuoTuningLayout) -> Binding<DuoFramingAdjustment> {
        let companion = store.companion
        return Binding(get: { framingDraft.value(for: companion, layout: layout) }, set: { value in
            var draft = framingDraft
            draft.set(value, companion: companion, layout: layout)
            if let data = try? JSONEncoder().encode(draft) { framingJSON = String(decoding: data, as: UTF8.self) }
        })
    }
    #endif

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

private struct DeviceHeaderHeight: PreferenceKey {
    static var defaultValue: CGFloat = 72
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
                    HStack(spacing: dense ? 6 : 10) {
                        Image(systemName: [SessionStatus.running, .preparing].contains(store.session.status) ? "pause.fill" : "play.fill")
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                        Text(buttonTitle)
                            .font(.system(dense ? .caption : .subheadline, weight: .semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(GlassKey(theme: theme, engaged: [SessionStatus.running, .preparing].contains(store.session.status)))
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityIdentifier("timer-primary")

                SlideToReset(theme: theme, compact: dense) { store.reset() }
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

/// The original painted ledge stays intact at every aspect ratio. Only its quiet
/// paper footer blends into the existing paper texture; architecture scales uniformly.
struct DeviceRoomBackdrop: View {
    let room: DuoRoom
    let format: DeviceRoomFormat
    let size: CGSize
    let ledgeY: CGFloat
    let characterX: CGFloat

    var body: some View {
        let frame = format.imageFrame(size: size, ledgeY: ledgeY, room: room, characterX: characterX)
        ZStack(alignment: .topLeading) {
            paperColor
                .overlay {
                    Image("paper-texture").resizable().scaledToFill()
                        .blendMode(.luminosity).opacity(0.18)
                }
                .frame(width: size.width, height: size.height).clipped()
            Image(format.asset(room: room)).resizable().interpolation(.none)
                .frame(width: frame.width, height: frame.height)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0),
                        .init(color: .black, location: 0.90), .init(color: .clear, location: 1)],
                        startPoint: .top, endPoint: .bottom)
                }
                .position(x: frame.midX, y: frame.midY)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var paperColor: Color {
        switch room {
        case .window: Color(hex: 0xfaecda)
        case .study: Color(hex: 0xffe3b9)
        case .river: Color(hex: 0xfce8d2)
        case .cafe: Color(hex: 0xffe0bc)
        case .academy: Color(hex: 0xf6e0dc)
        case .orbit: Color(hex: 0xfce5c6)
        }
    }

}

#if DEBUG
/// Temporary calibration overlay: it never participates in the scene's sizing.
private struct DuoFramingPanel: View {
    let companion: Companion
    let layout: DuoTuningLayout
    @Binding var value: DuoFramingAdjustment
    let exportJSON: String
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 10) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tune \(companion.name)").font(.subheadline.weight(.semibold))
                        Text(layout.title).font(.caption)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.down" : "chevron.up")
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded {
                tuningSlider("Scale", value: $value.scaleMultiplier, range: 0.3...1.8, step: 0.01, percentage: false)
                tuningSlider("Horizontal", value: $value.offsetXFraction, range: -0.5...0.5, step: 0.005)
                tuningSlider("Vertical", value: $value.offsetYFraction, range: -0.5...0.5, step: 0.005)
                HStack {
                    Button("Reset this") { value = .init() }
                    Spacer()
                    Button(copied ? "Copied" : "Copy all") {
                        UIPasteboard.general.string = exportJSON
                        copied = true
                    }
                    ShareLink(item: exportJSON) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share all Duo tuning values")
                }.font(.caption.weight(.semibold)).buttonStyle(.bordered)
                Text("Saved automatically. +X moves right; +Y moves down.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.7)))
        .onChange(of: exportJSON) { _, _ in copied = false }
    }

    private func tuningSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                              step: Double, percentage: Bool = true) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(percentage ? String(format: "%+.1f%%", value.wrappedValue * 100)
                                : String(format: "%.2f×", value.wrappedValue))
                    .monospacedDigit()
            }.font(.caption)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
        }
    }
}
#endif
