import SwiftUI

struct CompanionScene: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var audio: CompanionAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .title2) private var speechSpace: CGFloat = 82
    @ScaledMetric(relativeTo: .subheadline) private var nameHeight: CGFloat = 44
    var compact = false
    var openness = 1.0
    var sceneHeight: CGFloat?
    var tabletopHingeY: CGFloat?
    var showsSelector = true
    var showsName = true
    var showsBackdrop = true
    var roomLedgeY: CGFloat?
    var framingAdjustments: [Companion: DuoFramingAdjustment] = [:]
    @State private var selection: Companion = .mochi
    @State private var position = 0.0
    @State private var settling = false
    @State private var horizontal = false
    @GestureState private var touching = false
    @State private var settleTask: Task<Void, Never>?
    @State private var isGreeting = false
    @State private var greetingTask: Task<Void, Never>?

    private var theme: CompanionTheme { CompanionTheme(anchor) }
    private var selectorNameHeight: CGFloat { showsName ? nameHeight : 0 }
    private var companions: [Companion] { purchases.availableCompanions }
    private var anchor: Companion { companions.contains(selection) ? selection : companions[0] }
    private var pose: String { isGreeting ? "happy" : "idle" }
    private var neighbors: [Companion] {
        let list = companions
        let index = list.firstIndex(of: anchor) ?? 0
        return [list[(index + list.count - 1) % list.count], list[index], list[(index + 1) % list.count]]
    }

    var body: some View {
        GeometryReader { proxy in
            let artHeight = tabletopHingeY == nil && showsSelector ? max(100, proxy.size.height - selectorNameHeight - 24) : proxy.size.height
            let ledgeY = roomLedgeY ?? artHeight * 0.70
            VStack(spacing: 0) {
                ZStack {
                    CompanionArtwork(companions: neighbors, position: position,
                        width: proxy.size.width, height: artHeight,
                        layout: tabletopHingeY.map { .seated(hingeY: $0) }
                            ?? .perched(y: ledgeY),
                        reduceMotion: reduceMotion, poked: isGreeting, speech: speech,
                        framingAdjustments: framingAdjustments)
                    .contentShape(Rectangle())
                    .simultaneousGesture(sceneGesture(width: proxy.size.width))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text("%@, %@", anchor.name, L10n.text(pose.capitalized)))
                    .accessibilityValue(speech.map { "\($0.speaker.name): \($0.text)" } ?? "")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(L10n.text("Say hello to your companion"))
                    .accessibilityAction { greet() }
                    .accessibilityAdjustableAction { direction in
                        if direction == .increment { settle(1) }
                        else if direction == .decrement { settle(-1) }
                    }
                    .focusable()
                    .onKeyPress(.leftArrow) { settle(-1); return .handled }
                    .onKeyPress(.rightArrow) { settle(1); return .handled }
                    HStack {
                        stepButton(previous: true)
                        Spacer()
                        stepButton(previous: false)
                    }.padding(.horizontal, 12)
                }.frame(height: artHeight)
                if tabletopHingeY == nil && showsSelector { selector }

            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                if tabletopHingeY == nil && showsBackdrop {
                    ShelfCarouselBackdrop(companions: neighbors, position: position,
                        width: proxy.size.width, height: proxy.size.height, ledgeY: ledgeY)
                        .accessibilityHidden(true)
                }
            }
            .clipped()

        }
        // A shallow tabletop pane needs less empty stage beneath the face. Retain
        // scaled space for speech and the selector so accessibility sizes can scroll.
        .frame(height: tabletopHingeY != nil || roomLedgeY != nil || !showsSelector ? sceneHeight : max(sceneHeight ?? (compact ? 300 : 440),
                           speechSpace * 2 + selectorNameHeight + (compact ? 52 : 96)))
        .onAppear { selection = store.companion }
        .onChange(of: store.companion) { _, value in cancelRotation(); selection = value }
        .onChange(of: purchases.availableCompanions) { _, _ in cancelRotation(); selection = store.companion }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancelRotation() } }
        .onChange(of: touching) { _, active in
            // A gesture cancelled by scrolling/system interruption has no onEnded callback.
            if !active && horizontal && !settling { settle(0) }
        }
        .onChange(of: reduceMotion) { _, _ in cancelRotation() }
        .onDisappear { cancelRotation(); greetingTask?.cancel(); isGreeting = false }
    }

    private var selector: some View {
        VStack(spacing: 0) {
            if showsName {
                Text(anchor.name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.accent)
                    .frame(minHeight: nameHeight)
            }
            HStack(spacing: 7) {
                ForEach(companions) { companion in
                    Circle().fill(companion == anchor ? theme.accent : theme.accent.opacity(0.22))
                        .frame(width: 5, height: 5)
                }
            }.frame(height: 24).accessibilityHidden(true)
        }
    }

    private func sceneGesture(width: CGFloat) -> some Gesture {
        // One recognizer classifies taps and drags, so an aborted swipe cannot also greet.
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                guard !settling, abs(value.translation.width) >= 12,
                      abs(value.translation.width) > abs(value.translation.height) * 1.3 else { return }
                horizontal = true
                let travel = max(180, min(360, width * 0.55))
                position = min(1, max(-1, -value.translation.width / travel))
            }
            .onEnded { value in
                guard !settling else { return }
                if horizontal {
                    settle(InteractionGeometry.carouselDirection(x: value.translation.width, y: value.translation.height,
                        predictedX: value.predictedEndTranslation.width, width: width))
                } else if max(abs(value.translation.width), abs(value.translation.height)) < 6 {
                    greet()
                }
            }
    }

    private func stepButton(previous: Bool) -> some View {
        Button { settle(previous ? -1 : 1) } label: {
            Image(systemName: previous ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .modifier(GlassSurface(tint: theme.soft, radius: 22))
        }.buttonStyle(.plain)
            .accessibilityLabel(L10n.text(previous ? "Previous companion" : "Next companion"))
            .accessibilityValue(anchor.name)
    }

    private var speech: CompanionSpeech? {
        guard let text = audio.caption, let speaker = audio.captionCompanion, let cue = audio.captionCue else { return nil }
        return CompanionSpeech(id: audio.captionID, text: text, cue: cue, speaker: speaker)
    }

    private func settle(_ direction: Int) {
        guard !settling else { return }
        greetingTask?.cancel(); isGreeting = false
        let target = neighbors[direction + 1]
        settling = true
        withAnimation(.easeOut(duration: 0.28)) { position = Double(direction) }
        settleTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                if direction != 0 {
                    selection = target
                    if target.isAvailable(in: purchases.ownedProductIDs) { store.select(target) }
                }
                position = 0; horizontal = false; settling = false
            }
        }
    }

    private func cancelRotation() {
        settleTask?.cancel(); settleTask = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { position = 0; horizontal = false; settling = false }
    }

    private func greet() {
        guard store.session.status != .preparing, !isGreeting, !settling else { return }
        store.greet()
        greetingTask?.cancel(); isGreeting = true
        greetingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { isGreeting = false }
        }
    }
}

/// Every display uses the same registered idle/poked sheets, speech, and carousel.
/// Layout changes only the sprite frame and the carousel's geometric anchor.
struct CompanionArtwork: View, Animatable {
    let companions: [Companion]
    var position: Double
    let width: CGFloat
    let height: CGFloat
    let layout: CompanionArtworkLayout
    let reduceMotion: Bool
    let poked: Bool
    let speech: CompanionSpeech?
    var framingAdjustments: [Companion: DuoFramingAdjustment] = [:]
    var animatableData: Double { get { position } set { position = newValue } }

    var body: some View {
        ZStack {
            if case .seated(let hingeY) = layout {
                room(companions[1].duoRoom, hingeY: hingeY)
                let incoming = companions[position < 0 ? 0 : 2].duoRoom
                if incoming != companions[1].duoRoom {
                    room(incoming, hingeY: hingeY).opacity(min(1, abs(position)))
                }
            }
            ForEach(0..<3, id: \.self) { index in
                let companion = companions[index]
                let isPoked = poked && index == 1
                let registration = CompanionSpriteRegistration(companion, poked: isPoked)
                let baseline = layout.frame(companion: companion, width: width, height: height)
                let frame = (framingAdjustments[companion] ?? .init()).apply(to: baseline,
                    seat: registration.seat, pane: CGSize(width: width, height: height))
                SpriteSheetFrame(asset: companion.duoSprite, frame: isPoked ? 1 : 0)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .frame(width: width, height: height)
                    .overlay {
                        AvatarSpeechOverlay(speech: speech?.speaker == companion ? speech : nil,
                            companion: companion, pose: isPoked ? "happy" : "idle",
                            sceneMouth: CGPoint(x: (frame.minX + registration.mouth.x * frame.width) / max(1, width),
                                                y: (frame.minY + registration.mouth.y * frame.height) / max(1, height)),
                            compact: width < 600 || height < 400)
                    }
                    .modifier(CarouselMotion(offset: Double(index - 1) - position,
                        width: width, reduceMotion: reduceMotion, anchor: carouselAnchor))
            }
        }.frame(width: width, height: height)
    }

    private var carouselAnchor: UnitPoint {
        switch layout {
        case .seated(let y), .perched(let y): return UnitPoint(x: 0.5, y: y / max(1, height))
        case .platform: break
        }
        return .center
    }

    private func room(_ room: DuoRoom, hingeY: CGFloat) -> some View {
        let roomHeight = max(width / 1.5, hingeY / room.ledgeFraction)
        return Image(room.asset).resizable().interpolation(.none)
            .frame(width: roomHeight * 1.5, height: roomHeight)
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                    .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom)
            }
            .position(x: width / 2, y: hingeY + roomHeight * (0.5 - room.ledgeFraction))
            .frame(width: width, height: height)
            .allowsHitTesting(false)
    }
}

/// Rendering slices the two registered frames; the generated source stays intact.
private struct SpriteSheetFrame: View {
    let asset: String
    let frame: Int
    var body: some View {
        GeometryReader { proxy in
            Image(asset).resizable().interpolation(.none)
                .frame(width: proxy.size.width * 2, height: proxy.size.height)
                .offset(x: frame == 0 ? 0 : -proxy.size.width)
        }.clipped()
    }
}

/// Both layouts use the web carousel's orbit, turn, depth and visibility curve.
private struct CarouselMotion: ViewModifier {
    let offset: Double
    let width: CGFloat
    let reduceMotion: Bool
    var anchor: UnitPoint = .center

    func body(content: Content) -> some View {
        let frame = CarouselFrame(offset: offset)
        content
            .scaleEffect(reduceMotion ? 1 : frame.scale, anchor: anchor)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : frame.yaw), axis: (x: 0, y: 1, z: 0),
                              anchor: anchor, perspective: 0.6)
            .offset(x: reduceMotion ? 0 : frame.x * width)
            .opacity(reduceMotion ? max(0, 1 - abs(offset)) : frame.opacity)
            .zIndex(frame.depth)
    }
}

private struct ShelfCarouselBackdrop: View, Animatable {
    let companions: [Companion]
    var position: Double
    let width: CGFloat
    let height: CGFloat
    let ledgeY: CGFloat
    var animatableData: Double { get { position } set { position = newValue } }
    var body: some View {
        ZStack {
            backdrop(companions[1])
            let incoming = companions[position < 0 ? 0 : 2]
            if incoming.duoRoom != companions[1].duoRoom {
                backdrop(incoming).opacity(min(1, abs(position)))
            }
        }.frame(width: width, height: height)
    }
    private func backdrop(_ companion: Companion) -> some View {
        DeviceRoomBackdrop(room: companion.duoRoom,
            format: DeviceRoomFormat.resolve(size: CGSize(width: width, height: height), isPad: false),
            size: CGSize(width: width, height: height), ledgeY: ledgeY, characterX: width / 2)
    }
}

/// Storefronts and settings preview the same seated expressions as the live scene.
/// The painted shelf and every sprite share one seat coordinate, even in thumbnails.
struct CompanionShelfPreview: View {
    let companions: [Companion]
    var poked = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let ledgeY = size.height * 0.70
            let columnWidth = size.width / CGFloat(max(1, companions.count))
            ZStack(alignment: .topLeading) {
                if let first = companions.first {
                    DeviceRoomBackdrop(room: first.duoRoom,
                        format: DeviceRoomFormat.resolve(size: size, isPad: false),
                        size: size, ledgeY: ledgeY, characterX: size.width / 2)
                }
                ForEach(Array(companions.enumerated()), id: \.element.id) { index, companion in
                    let frame = DeviceRoomSprite.perchedFrame(companion: companion,
                        width: columnWidth, height: size.height, ledgeY: ledgeY,
                        horizontalInset: min(12, columnWidth * 0.08), topInset: 6, bottomInset: 4)
                    SpriteSheetFrame(asset: companion.duoSprite, frame: poked ? 1 : 0)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: CGFloat(index) * columnWidth + frame.midX, y: frame.midY)
                }
            }
            .frame(width: size.width, height: size.height).clipped()
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
