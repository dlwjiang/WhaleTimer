import Foundation
import Testing
@testable import BankeCore

private let start = Date(timeIntervalSince1970: 1_800_000_000)

@Test func lateWakeCompletesOnlyOneFocusAndRestoresExactlyOnce() throws {
    var state = StudyState()
    state.session.start(at: start)
    let data = try JSONEncoder().encode(state)
    var restored = StudyState.restore(data)
    let completedNow = restored.reconcile(at: start.addingTimeInterval(86_400))
    #expect(completedNow)
    #expect(restored.session.status == .complete)
    #expect(restored.completedInCycle == 1)
    #expect(restored.session.completedAt == start.addingTimeInterval(1500))
    let completed = try JSONEncoder().encode(restored)
    restored = StudyState.restore(completed)
    let completedAgain = restored.reconcile(at: start.addingTimeInterval(172_800))
    #expect(!completedAgain)
    #expect(restored.completedInCycle == 1)
}

@Test func pauseResumePreservesTimeAcrossRelaunch() throws {
    var state = StudyState()
    state.session.start(at: start)
    state.session.pause(at: start.addingTimeInterval(90))
    var restored = StudyState.restore(try JSONEncoder().encode(state))
    #expect(restored.session.remaining == 1410)
    restored.reconcile(at: start.addingTimeInterval(10_000))
    #expect(restored.session.remaining == 1410)
    restored.session.start(at: start.addingTimeInterval(10_000))
    restored.reconcile(at: start.addingTimeInterval(10_010))
    #expect(restored.session.remaining == 1400)
}

@Test func backwardsClockNeverRefillsTimer() {
    var session = FocusSession()
    session.start(at: start)
    session.reconcile(at: start.addingTimeInterval(200))
    session.reconcile(at: start.addingTimeInterval(100))
    #expect(session.remaining == 1300)
    session.reconcile(at: start.addingTimeInterval(201))
    #expect(session.remaining == 1299)
}

@Test func fourCompletedFocusSessionsEarnLongBreak() {
    var state = StudyState()
    for cycle in 1...4 {
        state.session.start(at: start)
        state.reconcile(at: start.addingTimeInterval(2000))
        #expect(state.completedInCycle == cycle)
        state.advance()
        #expect(state.session.phase == (cycle == 4 ? .longBreak : .shortBreak))
        #expect(state.session.status == .ready)
        state.session.start(at: start)
        state.reconcile(at: start.addingTimeInterval(2000))
        state.advance()
    }
    #expect(state.completedInCycle == 0)
    #expect(state.session.phase == .focus)
}

@Test func resetAndCompanionChangesNeverGrantFocusCredit() {
    var state = StudyState()
    state.session.start(at: start)
    state.reconcile(at: start.addingTimeInterval(500))
    let deadline = state.session.deadline
    state.companion = .pip
    #expect(state.session.deadline == deadline)
    state.reset()
    #expect(state.session.status == .ready)
    #expect(state.completedInCycle == 0)
}

@Test func pauseOnDeadlineStillCreditsSessionThroughState() {
    var state = StudyState()
    state.session.start(at: start)
    state.reconcile(at: start.addingTimeInterval(1500))
    state.session.pause(at: start.addingTimeInterval(1500))
    #expect(state.completedInCycle == 1)
    #expect(state.session.status == .complete)
}

@Test func invalidStorageAndDurationsRecover() {
    #expect(StudyState.restore(Data("bad json".utf8)).session.status == .ready)
    var session = FocusSession()
    session.prepare(.focus, seconds: .infinity)
    #expect(session.duration == 1500)
    session.prepare(.focus, seconds: -10)
    #expect(session.duration == 1)
    #expect(session.isValid)
}

@Test func skipLongBreakStartsAFreshCycle() {
    var state = StudyState()
    state.completedInCycle = 4
    state.session.prepare(.longBreak, seconds: 900)
    state.reset()
    #expect(state.completedInCycle == 0)
    state.session.start(at: start)
    state.reconcile(at: start.addingTimeInterval(1500))
    #expect(state.nextPhase == .shortBreak)
}

@Test func completionTimestampUsesDeadlineRatherThanReopenTime() {
    var state = StudyState()
    state.session.start(at: start)
    state.reconcile(at: start.addingTimeInterval(172_800))
    #expect(state.session.completedAt == start.addingTimeInterval(1500))
    #expect(state.completedInCycle == 1)
}

@Test func invalidStoredSettingsRecoverToUsableDefaults() throws {
    var state = StudyState()
    state.settings.focusMinutes = -100
    let restored = StudyState.restore(try JSONEncoder().encode(state))
    #expect(restored.settings.focusMinutes == 25)
}

@Test func legacyJournalStateRestoresTimerAndCycleWithoutKeepingHistory() throws {
    var state = StudyState()
    state.companion = .pip
    state.intention = "Read a chapter"
    state.completedInCycle = 3
    state.session.start(at: start)
    state.session.pause(at: start.addingTimeInterval(90))
    let data = try JSONEncoder().encode(state)
    var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    legacy["records"] = [["id": UUID().uuidString, "finishedAt": 800_000_000,
                           "seconds": 1500, "companion": "pip", "intention": "Earlier session"]]
    var restored = StudyState.restore(try JSONSerialization.data(withJSONObject: legacy))
    #expect(restored.session == state.session)
    #expect(restored.companion == .pip)
    #expect(restored.intention == state.intention)
    #expect(restored.completedInCycle == 3)
    let saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
    #expect(saved["records"] == nil)
    restored.session.start(at: start.addingTimeInterval(100))
    restored.reconcile(at: start.addingTimeInterval(2000))
    #expect(restored.completedInCycle == 4)
    #expect(restored.nextPhase == .longBreak)
}
