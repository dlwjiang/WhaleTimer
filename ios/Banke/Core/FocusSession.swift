import Foundation

enum SessionPhase: String, Codable, Sendable {
    case focus, shortBreak, longBreak
    var title: String {
        switch self {
        case .focus: L10n.text("Focus")
        case .shortBreak: L10n.text("Short break")
        case .longBreak: L10n.text("Long break")
        }
    }
}

enum SessionStatus: String, Codable, Sendable { case ready, preparing, preparationPaused, running, paused, complete }

struct TimerSettings: Codable, Equatable, Sendable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var soundEnabled = true
    var effectsEnabled = true
    var voicesEnabled = true
    var notificationsEnabled = false
    var keepAwake = false

    init() {}
    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, soundEnabled, effectsEnabled, voicesEnabled, notificationsEnabled, keepAwake
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
        shortBreakMinutes = try values.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? 5
        longBreakMinutes = try values.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
        soundEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        effectsEnabled = try values.decodeIfPresent(Bool.self, forKey: .effectsEnabled) ?? true
        voicesEnabled = try values.decodeIfPresent(Bool.self, forKey: .voicesEnabled) ?? true
        notificationsEnabled = try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        keepAwake = try values.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? false
    }

    func seconds(for phase: SessionPhase) -> TimeInterval {
        switch phase {
        case .focus: Double(min(180, max(1, focusMinutes)) * 60)
        case .shortBreak: Double(min(60, max(1, shortBreakMinutes)) * 60)
        case .longBreak: Double(min(90, max(1, longBreakMinutes)) * 60)
        }
    }
}

/// A deadline, never the number of UI ticks, determines completion.
/// Breaks start explicitly so time away cannot fabricate completed focus sessions.
struct FocusSession: Codable, Equatable, Sendable {
    private(set) var id = UUID()
    private(set) var phase: SessionPhase = .focus
    private(set) var status: SessionStatus = .ready
    private(set) var duration: TimeInterval = 25 * 60
    private(set) var remaining: TimeInterval = 25 * 60
    private(set) var deadline: Date?
    private(set) var completedAt: Date?

    var progress: Double { 1 - remaining / duration }

    mutating func prepare(_ phase: SessionPhase, seconds: TimeInterval) {
        self = FocusSession()
        self.phase = phase
        self.duration = seconds.isFinite ? min(10800, max(1, seconds)) : 1500
        self.remaining = duration
    }

    mutating func beginPreparation() {
        guard phase == .focus, status == .ready || status == .preparationPaused else { return }
        status = .preparing
    }
    mutating func finishPreparation(at now: Date) {
        guard status == .preparing else { return }
        status = .ready
        start(at: now)
    }

    mutating func start(at now: Date) {
        guard status == .ready || status == .paused else { return }
        deadline = now.addingTimeInterval(remaining)
        status = .running
    }

    @discardableResult
    mutating func reconcile(at now: Date) -> Bool {
        guard status == .running, let deadline else { return false }
        // A backwards clock adjustment must not refill the countdown.
        remaining = min(remaining, max(0, deadline.timeIntervalSince(now)))
        guard remaining == 0 else { return false }
        completedAt = deadline
        self.deadline = nil
        status = .complete
        return true
    }

    mutating func pause(at now: Date) {
        if status == .preparing { status = .preparationPaused; return }
        reconcile(at: now)
        guard status == .running else { return }
        deadline = nil
        status = .paused
    }

    var isValid: Bool {
        duration.isFinite && duration >= 1 && duration <= 10800 &&
        remaining.isFinite && remaining >= 0 && remaining <= duration &&
        ((status == .running) == (deadline != nil)) &&
        ((status == .complete) == (completedAt != nil)) &&
        (status != .complete || remaining == 0) &&
        (![SessionStatus.ready, .preparing, .preparationPaused].contains(status) || remaining == duration) &&
        (![SessionStatus.preparing, .preparationPaused].contains(status) || phase == .focus) &&
        (deadline?.timeIntervalSince1970.isFinite ?? true) &&
        (completedAt?.timeIntervalSince1970.isFinite ?? true)
    }
}

struct StudyState: Codable, Sendable {
    var version = 1
    var settings = TimerSettings()
    var session = FocusSession()
    var companion: Companion = .mochi
    var intention = ""
    var completedInCycle = 0

    var nextPhase: SessionPhase {
        session.phase == .focus ? (completedInCycle >= 4 ? .longBreak : .shortBreak) : .focus
    }

    @discardableResult
    mutating func reconcile(at now: Date) -> Bool {
        guard session.reconcile(at: now) else { return false }
        // Only the running → complete transition advances the current break cycle.
        // Reopening a completed session cannot count it a second time.
        if session.phase == .focus {
            completedInCycle = min(4, completedInCycle + 1)
        }
        return true
    }

    mutating func advance() {
        guard session.status == .complete else { return }
        let next = nextPhase
        if next == .focus && completedInCycle >= 4 { completedInCycle = 0 }
        session.prepare(next, seconds: settings.seconds(for: next))
    }

    mutating func reset() {
        if completedInCycle >= 4 { completedInCycle = 0 }
        session.prepare(.focus, seconds: settings.seconds(for: .focus))
    }

    static func restore(_ data: Data?) -> StudyState {
        guard let data, var state = try? JSONDecoder().decode(Self.self, from: data),
              state.version == 1, state.session.isValid,
              (1...180).contains(state.settings.focusMinutes),
              (1...60).contains(state.settings.shortBreakMinutes),
              (1...90).contains(state.settings.longBreakMinutes),
              (0...4).contains(state.completedInCycle)
        else { return StudyState() }
        if state.session.status == .preparing { state.session.pause(at: Date()) }
        return state
    }
}
