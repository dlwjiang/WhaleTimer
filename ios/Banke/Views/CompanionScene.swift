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
    @State private var selection: Companion = .mochi
    @State private var position = 0.0
    @State private var settling = false
    @State private var horizontal = false
    @GestureState private var touching = false
    @State private var settleTask: Task<Void, Never>?
    @State private var isGreeting = false
    @State private var greetedAt = Date.distantPast
    @State private var greetingTask: Task<Void, Never>?

    private var theme: CompanionTheme { CompanionTheme(anchor) }
    private var companions: [Companion] { purchases.availableCompanions }
    private var anchor: Companion { companions.contains(selection) ? selection : companions[0] }
    private var pose: String {
        if isGreeting || (audio.speaking && audio.captionCompanion == store.companion) || store.session.status == .complete { return "happy" }
        if store.session.phase != .focus { return "rest" }
        return store.session.status == .running ? "focus" : "idle"
    }
    private var neighbors: [Companion] {
        let list = companions
        let index = list.firstIndex(of: anchor) ?? 0
        return [list[(index + list.count - 1) % list.count], list[index], list[(index + 1) % list.count]]
    }

    var body: some View {
        GeometryReader { proxy in
            let artHeight = tabletopHingeY == nil && showsSelector ? max(100, proxy.size.height - nameHeight - 24) : proxy.size.height
            VStack(spacing: 0) {
                ZStack {
                    Group {
                        if let hingeY = tabletopHingeY {
                            TabletopArtwork(companions: neighbors, pose: pose, position: position,
                                width: proxy.size.width, height: artHeight, hingeY: hingeY,
                                reduceMotion: reduceMotion, poked: isGreeting, speech: speech)
                        } else {
                            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion || scenePhase != .active)) { timeline in
                                let breath = reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 1.5)
                                CylinderArtwork(companions: neighbors, pose: pose, position: position,
                                                width: proxy.size.width, height: artHeight, breath: breath,
                                                reduceMotion: reduceMotion, speech: speech,
                                                pokeElapsed: isGreeting ? timeline.date.timeIntervalSince(greetedAt) : nil)
                            }
                        }
                    }
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
                if tabletopHingeY == nil {
                    CylinderBackdrop(companions: neighbors, position: position, width: proxy.size.width, height: proxy.size.height)
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18), .init(color: .black, location: 0.82), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                        }
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12), .init(color: .black, location: 0.88), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
                        }
                        .opacity(0.85 + openness * 0.15).accessibilityHidden(true)
                }
            }
            .clipped()

        }
        // A shallow tabletop pane needs less empty stage beneath the face. Retain
        // scaled space for speech and the selector so accessibility sizes can scroll.
        .frame(height: tabletopHingeY != nil || !showsSelector ? sceneHeight : max(sceneHeight ?? (compact ? 300 : 440),
                           speechSpace * 2 + nameHeight + (compact ? 52 : 96)))
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
            Text(anchor.name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.accent)
                .frame(minHeight: nameHeight)
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
        greetingTask?.cancel(); greetedAt = Date(); isGreeting = true
        greetingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { isGreeting = false }
        }
    }
}

/// Rooms remain fixed at the hinge; only the transparent companion layers turn.
private struct TabletopArtwork: View, Animatable {
    let companions: [Companion]
    let pose: String
    var position: Double
    let width: CGFloat
    let height: CGFloat
    let hingeY: CGFloat
    let reduceMotion: Bool
    let poked: Bool
    let speech: CompanionSpeech?
    var animatableData: Double { get { position } set { position = newValue } }

    var body: some View {
        ZStack {
            room(companions[1].duoRoom)
            let incoming = companions[position < 0 ? 0 : 2].duoRoom
            if incoming != companions[1].duoRoom {
                room(incoming).opacity(min(1, abs(position)))
            }
            ForEach(0..<3, id: \.self) { index in
                let companion = companions[index]
                let offset = Double(index - 1) - position
                let registration = DuoSpriteRegistration(companion, poked: poked && index == 1)
                let spriteHeight = min(max(width / 1.5, hingeY / 0.78), hingeY / registration.seat) * registration.scale
                let spriteWidth = spriteHeight * registration.aspect
                SpriteSheetFrame(asset: companion.duoSprite, frame: poked && index == 1 ? 1 : 0)
                    .frame(width: spriteWidth, height: spriteHeight)
                    .overlay {
                        AvatarSpeechOverlay(speech: speech?.speaker == companion ? speech : nil,
                            companion: companion, pose: pose, sceneMouth: registration.mouth)
                    }
                    .position(x: width / 2, y: hingeY + spriteHeight * (0.5 - registration.seat))
                    .frame(width: width, height: height)
                    .modifier(CarouselMotion(offset: offset, width: width, reduceMotion: reduceMotion,
                        anchor: UnitPoint(x: 0.5, y: hingeY / max(1, height))))
            }
        }.frame(width: width, height: height)
    }

    private func room(_ room: DuoRoom) -> some View {
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

private struct DuoSpriteRegistration {
    let aspect: CGFloat
    let seat: CGFloat
    let mouth: CGPoint
    let scale: CGFloat
    init(_ companion: Companion, poked: Bool = false) {
        let imageSize = UIImage(named: companion.duoSprite)?.size ?? CGSize(width: 3, height: 1)
        aspect = imageSize.width / 2 / max(1, imageSize.height)
        // Scale about the seat so smaller companions still rest on the ledge.
        switch companion {
        case .atlas: scale = 0.70
        case .mochi, .pebble, .bean, .maple: scale = 0.74
        default: scale = 1
        }
        switch companion {
        case .mochi: seat = 0.77; mouth = CGPoint(x: 0.591, y: poked ? 0.401 : 0.388)
        case .pip: seat = 0.72; mouth = CGPoint(x: 0.558, y: 0.327)
        case .pebble: seat = 0.78; mouth = CGPoint(x: poked ? 0.460 : 0.464, y: poked ? 0.345 : 0.328)
        case .maple: seat = 0.74; mouth = CGPoint(x: poked ? 0.581 : 0.576, y: poked ? 0.335 : 0.328)
        case .bean: seat = 0.85; mouth = CGPoint(x: 0.600, y: poked ? 0.397 : 0.375)
        case .jun: seat = 0.72; mouth = CGPoint(x: 0.545, y: poked ? 0.350 : 0.343)
        case .wisp: seat = 0.72; mouth = CGPoint(x: poked ? 0.562 : 0.613, y: 0.411)
        case .luna: seat = 0.70; mouth = CGPoint(x: 0.548, y: 0.312)
        case .atlas: seat = 0.93; mouth = CGPoint(x: 0.566, y: poked ? 0.315 : 0.298)
        case .nova: seat = 0.73; mouth = CGPoint(x: 0.552, y: poked ? 0.343 : 0.335)
        case .orbit: seat = 0.76; mouth = CGPoint(x: 0.560, y: 0.433)
        case .comet: seat = 0.74; mouth = CGPoint(x: 0.535, y: poked ? 0.436 : 0.425)
        }
    }
}

private struct CylinderArtwork: View, Animatable {
    let companions: [Companion]
    let pose: String
    var position: Double
    let width: CGFloat
    let height: CGFloat
    let breath: Double
    let reduceMotion: Bool
    let speech: CompanionSpeech?
    var pokeElapsed: TimeInterval? = nil
    var animatableData: Double { get { position } set { position = newValue } }
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let offset = Double(index - 1) - position
                let reaction = !reduceMotion && index == 1 ? pokeReaction : 0
                let artSize = min(width - 54, 500, height)
                let placement = companions[index].platformOffset
                Image("\(companions[index].rawValue)-\(pose)")
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: min(width - 54, 500), height: height)
                    .overlay {
                        AvatarSpeechOverlay(speech: speech?.speaker == companions[index] ? speech : nil,
                                            companion: companions[index], pose: pose)
                    }
                    .scaleEffect(x: 1 + reaction * 0.04, y: 1 + breath * 0.007 - reaction * 0.04, anchor: .bottom)
                    .rotationEffect(.degrees(reaction * 4), anchor: .bottom)
                    .offset(x: placement.x * artSize,
                            y: placement.y * artSize + breath * 2 - abs(reaction) * 6)
                    .modifier(CarouselMotion(offset: offset, width: width, reduceMotion: reduceMotion))
            }
        }.frame(width: width, height: height)
    }
    private var pokeReaction: Double {
        guard let elapsed = pokeElapsed, elapsed >= 0, elapsed < 0.7 else { return 0 }
        return sin(elapsed * 24) * exp(-elapsed * 5)
    }
}

private extension Companion {
    /// Correct the transparent padding in the original square pose images.
    var platformOffset: CGPoint {
        switch self {
        case .pebble, .wisp, .comet: CGPoint(x: 0, y: 0.065)
        case .pip: CGPoint(x: -0.055, y: 0)
        default: .zero
        }
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

private struct CylinderBackdrop: View, Animatable {
    let companions: [Companion]
    var position: Double
    let width: CGFloat
    let height: CGFloat
    var animatableData: Double { get { position } set { position = newValue } }
    var body: some View {
        ZStack {
            backdrop(companions[1])
            let incoming = companions[position < 0 ? 0 : 2]
            if CompanionTheme(incoming).backdrop != CompanionTheme(companions[1]).backdrop {
                backdrop(incoming).opacity(min(1, abs(position)))
            }
        }.frame(width: width, height: height)
    }
    private func backdrop(_ companion: Companion) -> some View {
        Image(CompanionTheme(companion).backdrop).resizable().scaledToFill()
            .frame(width: width, height: height * 1.65).clipped()
            .position(x: width / 2, y: height * 0.42)
    }
}
