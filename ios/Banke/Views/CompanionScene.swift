import SwiftUI

struct CompanionScene: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var audio: CompanionAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .title2) private var speechSpace: CGFloat = 82
    var compact = false
    var openness = 1.0
    var sceneHeight: CGFloat?
    @State private var anchor: Companion = .mochi
    @State private var position = 0.0
    @State private var settling = false
    @State private var horizontal = false
    @GestureState private var touching = false
    @State private var settleTask: Task<Void, Never>?
    @State private var isGreeting = false
    @State private var greetingTask: Task<Void, Never>?
    @State private var previewPack: CompanionPack?

    private var theme: CompanionTheme { CompanionTheme(anchor) }
    private var isLocked: Bool { !anchor.isAvailable(in: purchases.ownedProductIDs) }
    private var pose: String {
        if isLocked { return "idle" }
        if isGreeting || (audio.speaking && audio.captionCompanion == store.companion) || store.session.status == .complete { return "happy" }
        if store.session.phase != .focus { return "rest" }
        return store.session.status == .running ? "focus" : "idle"
    }
    private var neighbors: [Companion] {
        let list = Companion.allCases
        let index = list.firstIndex(of: anchor) ?? 0
        return [list[(index + list.count - 1) % list.count], list[index], list[(index + 1) % list.count]]
    }

    var body: some View {
        GeometryReader { proxy in
            let artHeight = max(100, proxy.size.height - 68)
            VStack(spacing: 0) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion || scenePhase != .active)) { timeline in
                        let breath = reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 1.5)
                        CylinderArtwork(companions: neighbors, pose: pose, position: position,
                                        width: proxy.size.width, height: artHeight, breath: breath,
                                        reduceMotion: reduceMotion, speech: speech,
                                        ownedProductIDs: purchases.ownedProductIDs)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(sceneGesture(width: proxy.size.width))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text("%@, %@", anchor.name, L10n.text(isLocked ? "Locked" : pose.capitalized)))
                    .accessibilityValue(speech.map { "\($0.speaker.name): \($0.text)" } ?? "")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(L10n.text(isLocked ? "View companion packs" : "Say hello to your companion"))
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
                Group {
                    if isLocked {
                        Button { previewPack = anchor.pack } label: {
                            HStack(spacing: 8) {
                                Text(anchor.name).fontWeight(.semibold)
                                Label("View pack", systemImage: "lock.fill")
                            }
                            .font(.subheadline).foregroundStyle(theme.accent)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .modifier(GlassSurface(tint: theme.soft, radius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text("%@, %@", anchor.name, L10n.text("Locked")))
                        .accessibilityHint("View companion packs")
                        .accessibilityIdentifier("locked-companion-pack")
                    } else {
                        Text(anchor.name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.accent)
                    }
                }.frame(minHeight: 44)
                HStack(spacing: 7) {
                    ForEach(Companion.allCases) { companion in
                        if companion.isAvailable(in: purchases.ownedProductIDs) {
                            Circle().fill(companion == anchor ? theme.accent : theme.accent.opacity(0.22))
                                .frame(width: 5, height: 5)
                        } else {
                            Image(systemName: "lock.fill").font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(theme.accent.opacity(companion == anchor ? 1 : 0.35))
                                .frame(width: 5, height: 7)
                        }
                    }
                }.frame(height: 24).accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                CylinderBackdrop(companions: neighbors, position: position, width: proxy.size.width, height: proxy.size.height)
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18), .init(color: .black, location: 0.82), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                    }
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12), .init(color: .black, location: 0.88), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
                    }
                    .opacity(0.85 + openness * 0.15).accessibilityHidden(true)
            }
            .clipped()

        }
        .frame(height: max(sceneHeight ?? (compact ? 300 : 440), speechSpace * 2 + 140))
        .sheet(item: $previewPack, onDismiss: {
            cancelRotation(); anchor = store.companion
        }) { pack in CompanionShopView(initialPack: pack) }
        .onAppear { anchor = store.companion }
        .onChange(of: store.companion) { _, value in cancelRotation(); anchor = value }
        .onChange(of: purchases.availableCompanions) { _, _ in cancelRotation(); anchor = store.companion }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancelRotation() } }
        .onChange(of: touching) { _, active in
            // A gesture cancelled by scrolling/system interruption has no onEnded callback.
            if !active && horizontal && !settling { settle(0) }
        }
        .onChange(of: reduceMotion) { _, _ in cancelRotation() }
        .onDisappear { cancelRotation(); greetingTask?.cancel(); isGreeting = false }
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
        guard !isLocked else { return nil }
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
                    // Browsing a locked character is not an entitlement or an active selection.
                    anchor = target
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
        if isLocked { previewPack = anchor.pack; return }
        guard store.session.status != .preparing else { return }
        store.greet()
        greetingTask?.cancel(); isGreeting = true
        greetingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { isGreeting = false }
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
    let ownedProductIDs: Set<String>
    var animatableData: Double { get { position } set { position = newValue } }
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let offset = Double(index - 1) - position
                let frame = CarouselFrame(offset: offset)
                let locked = !companions[index].isAvailable(in: ownedProductIDs)
                Image("\(companions[index].rawValue)-\(locked ? "idle" : pose)")
                    .resizable().interpolation(.none).scaledToFit()
                    .saturation(locked ? 0.12 : 1).opacity(locked ? 0.65 : 1)
                    .frame(width: min(width - 54, 500), height: height)
                    .overlay {
                        AvatarSpeechOverlay(speech: speech?.speaker == companions[index] ? speech : nil,
                                            companion: companions[index], pose: pose)
                    }
                    .scaleEffect(x: 1, y: 1 + breath * 0.007, anchor: .bottom)
                    .offset(y: breath * 2)
                    .scaleEffect(reduceMotion ? 1 : frame.scale)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : frame.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .offset(x: reduceMotion ? 0 : frame.x * width)
                    .opacity(reduceMotion ? max(0, 1 - abs(offset)) : frame.opacity)
                    .zIndex(frame.depth)
            }
        }.frame(width: width, height: height)
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
            backdrop(companions[position < 0 ? 0 : 2]).opacity(min(1, abs(position)))
        }.frame(width: width, height: height)
    }
    private func backdrop(_ companion: Companion) -> some View {
        Image(CompanionTheme(companion).backdrop).resizable().scaledToFill()
            .frame(width: width, height: height * 1.65).clipped()
            .position(x: width / 2, y: height * 0.42)
    }
}
