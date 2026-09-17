import Foundation
import XCTest
@testable import Passata

@MainActor
final class TimerStatePersistenceTests: XCTestCase {
    func testSaveAndLoadRoundTripPreservesEverySnapshotField() throws {
        let suite = "PassataTests.TimerStatePersistence." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "timer-state"
        let writer = UserDefaultsTimerStateStore(defaults: defaults, key: key)
        let snapshots = [
            TimerSnapshot(phase: .focus, status: .idle, sessionIndex: 1, endDate: nil, pausedRemaining: nil),
            TimerSnapshot(phase: .shortBreak, status: .running, sessionIndex: 2,
                          endDate: Date(timeIntervalSinceReferenceDate: 1_234.75), pausedRemaining: nil),
            TimerSnapshot(phase: .longBreak, status: .paused, sessionIndex: 4, endDate: nil, pausedRemaining: 89.75),
            TimerSnapshot(phase: .focus, status: .complete, sessionIndex: 3, endDate: nil, pausedRemaining: nil)
        ]

        for snapshot in snapshots {
            writer.save(snapshot)
            XCTAssertNotNil(defaults.data(forKey: key))
            let reader = UserDefaultsTimerStateStore(defaults: defaults, key: key)
            let loaded = try XCTUnwrap(reader.load())
            XCTAssertEqual(loaded.phase, snapshot.phase)
            XCTAssertEqual(loaded.status, snapshot.status)
            XCTAssertEqual(loaded.sessionIndex, snapshot.sessionIndex)
            XCTAssertEqual(loaded.endDate, snapshot.endDate)
            XCTAssertEqual(loaded.pausedRemaining, snapshot.pausedRemaining)
        }
    }

    func testMissingMalformedAndPartialDataFallBackToFreshTimer() throws {
        let suite = "PassataTests.TimerStatePersistence." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "timer-state"
        let store = UserDefaultsTimerStateStore(defaults: defaults, key: key)
        XCTAssertNil(store.load())

        let invalidValues: [Any] = [
            "not stored as Data",
            Data("not JSON".utf8),
            Data(#"{"phase":"focus","status":"running"}"#.utf8),
            Data(#"{"phase":"focus","status":"idle","sessionIndex":"two"}"#.utf8)
        ]
        for value in invalidValues {
            defaults.set(value, forKey: key)
            XCTAssertNil(store.load())
            let engine = TimerEngine(durationProvider: PersistenceDurationProvider(), persister: store)
            XCTAssertEqual(engine.phase, .focus)
            XCTAssertEqual(engine.status, .idle)
            XCTAssertEqual(engine.sessionIndex, 1)
            XCTAssertEqual(engine.remainingSeconds, 1500)
            XCTAssertEqual(engine.currentRenderState, .idle(phaseDurationSeconds: 1500))
        }
    }
}

private struct PersistenceDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int {
        PhaseDurations.classic.seconds(for: phase)
    }
}
