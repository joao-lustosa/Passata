import Foundation
import Testing
@testable import Passata

@Test(arguments: [
    TimerSnapshot(phase: .focus, status: .idle, sessionIndex: 1, endDate: nil, pausedRemaining: nil),
    TimerSnapshot(phase: .shortBreak, status: .running, sessionIndex: 2,
                  endDate: Date(timeIntervalSinceReferenceDate: 1_234.75), pausedRemaining: nil),
    TimerSnapshot(phase: .longBreak, status: .paused, sessionIndex: 4, endDate: nil, pausedRemaining: 89.75),
    TimerSnapshot(phase: .focus, status: .complete, sessionIndex: 3, endDate: nil, pausedRemaining: nil)
])
@MainActor
func saveAndLoadRoundTripPreservesEverySnapshotField(snapshot: TimerSnapshot) throws {
    let suite = "PassataTests.TimerStatePersistence." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "timer-state"
    let writer = UserDefaultsTimerStateStore(defaults: defaults, key: key)
    writer.save(snapshot)
    #expect(defaults.data(forKey: key) != nil)
    let reader = UserDefaultsTimerStateStore(defaults: defaults, key: key)
    let loaded = try #require(reader.load())
    #expect(loaded.phase == snapshot.phase)
    #expect(loaded.status == snapshot.status)
    #expect(loaded.sessionIndex == snapshot.sessionIndex)
    #expect(loaded.endDate == snapshot.endDate)
    #expect(loaded.pausedRemaining == snapshot.pausedRemaining)
}

@Test
@MainActor
func missingKeyReturnsNilAndFallsBackToFreshTimer() throws {
    let suite = "PassataTests.TimerStatePersistence." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = UserDefaultsTimerStateStore(defaults: defaults, key: "timer-state")
    #expect(store.load() == nil)
}

@Test(arguments: [
    "not stored as Data",
    Data("not JSON".utf8),
    Data(#"{"phase":"focus","status":"running"}"#.utf8),
    Data(#"{"phase":"focus","status":"idle","sessionIndex":"two"}"#.utf8)
] as [any Sendable])
@MainActor
func malformedDataFallsBackToFreshTimer(_ value: any Sendable) throws {
    let suite = "PassataTests.TimerStatePersistence." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "timer-state"
    let store = UserDefaultsTimerStateStore(defaults: defaults, key: key)
    defaults.set(value, forKey: key)
    #expect(store.load() == nil)
    let engine = TimerEngine(durationProvider: PersistenceDurationProvider(), persister: store)
    #expect(engine.phase == .focus)
    #expect(engine.status == .idle)
    #expect(engine.sessionIndex == 1)
    #expect(engine.remainingSeconds == 1500)
    #expect(engine.currentRenderState == .idle(phaseDurationSeconds: 1500))
}

@Test
@MainActor
func missingOptionalSnapshotFieldsDecodeWithoutAffectingOtherValues() throws {
    let running = TimerSnapshot(
        phase: .shortBreak,
        status: .running,
        sessionIndex: 2,
        endDate: Date(timeIntervalSinceReferenceDate: 1_234.75),
        pausedRemaining: nil
    )
    var runningObject = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(running)) as? [String: Any])
    runningObject.removeValue(forKey: "endDate")
    let runningWithoutEndDate = try JSONDecoder().decode(
        TimerSnapshot.self,
        from: JSONSerialization.data(withJSONObject: runningObject)
    )
    #expect(runningWithoutEndDate.phase == running.phase)
    #expect(runningWithoutEndDate.status == running.status)
    #expect(runningWithoutEndDate.sessionIndex == running.sessionIndex)
    #expect(runningWithoutEndDate.endDate == nil)

    let paused = TimerSnapshot(
        phase: .longBreak,
        status: .paused,
        sessionIndex: 4,
        endDate: nil,
        pausedRemaining: 89.75
    )
    var pausedObject = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(paused)) as? [String: Any])
    pausedObject.removeValue(forKey: "pausedRemaining")
    let pausedWithoutRemaining = try JSONDecoder().decode(
        TimerSnapshot.self,
        from: JSONSerialization.data(withJSONObject: pausedObject)
    )
    #expect(pausedWithoutRemaining.phase == paused.phase)
    #expect(pausedWithoutRemaining.status == paused.status)
    #expect(pausedWithoutRemaining.sessionIndex == paused.sessionIndex)
    #expect(pausedWithoutRemaining.pausedRemaining == nil)
}

@Test(arguments: [
    "not stored as Data",
    Data("not JSON".utf8),
    Data(#"{"phase":"focus","status":"running"}"#.utf8)
] as [any Sendable])
@MainActor
func malformedTimerStateIsPreservedBeforeAnOrdinarySave(_ value: any Sendable) throws {
    let suite = "PassataTests.TimerStateCorruption." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "timer-state"
    defaults.set(value, forKey: key)
    let store = UserDefaultsTimerStateStore(defaults: defaults, key: key)

    let engine = TimerEngine(durationProvider: PersistenceDurationProvider(), persister: store)
    engine.start()

    let archived = try #require(defaults.object(forKey: key + ".unreadable"))
    #expect((archived as? Data) == (value as? Data))
    #expect((archived as? String) == (value as? String))
    let replacement = try #require(defaults.data(forKey: key))
    let decoded = try JSONDecoder().decode(TimerSnapshot.self, from: replacement)
    #expect(decoded.phase == .focus)
    #expect(decoded.status == .running)
    #expect(decoded.sessionIndex == 1)
}

private struct PersistenceDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int {
        PhaseDurations.classic.seconds(for: phase)
    }
}
