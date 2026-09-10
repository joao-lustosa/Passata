import Foundation
import XCTest
@testable import Passata

@MainActor
final class TimerEngineTests: XCTestCase {
    func testPhaseSequencingCoversEveryTransition() {
        let beforeCycleEnd = Phase.focus.next(sessionIndex: 3, sessionsPerCycle: 4)
        XCTAssertEqual(beforeCycleEnd.phase, .shortBreak)
        XCTAssertEqual(beforeCycleEnd.sessionIndex, 3)

        let cycleEnd = Phase.focus.next(sessionIndex: 4, sessionsPerCycle: 4)
        XCTAssertEqual(cycleEnd.phase, .longBreak)
        XCTAssertEqual(cycleEnd.sessionIndex, 4)

        let afterShortBreak = Phase.shortBreak.next(sessionIndex: 2, sessionsPerCycle: 4)
        XCTAssertEqual(afterShortBreak.phase, .focus)
        XCTAssertEqual(afterShortBreak.sessionIndex, 3)

        let afterLongBreak = Phase.longBreak.next(sessionIndex: 4, sessionsPerCycle: 4)
        XCTAssertEqual(afterLongBreak.phase, .focus)
        XCTAssertEqual(afterLongBreak.sessionIndex, 1)
    }

    func testStartPauseAndResumeUseTheInjectedClock() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let store = RecordingTimerStateStore()
        let engine = makeEngine(clock: clock, store: store)

        engine.start()
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(store.latest?.endDate, clock.now.addingTimeInterval(120))

        clock.now = clock.now.addingTimeInterval(30)
        engine.pause()
        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.remainingSeconds, 90)

        clock.now = clock.now.addingTimeInterval(500)
        engine.resume()
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(store.latest?.endDate, clock.now.addingTimeInterval(90))
    }

    func testResetIsIdleNoOpAndOtherwiseKeepsPhaseAndSession() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let store = RecordingTimerStateStore()
        let engine = makeEngine(clock: clock, store: store)

        engine.onReset()
        XCTAssertNil(store.latest)
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.sessionIndex, 1)

        engine.onSkip()
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.sessionIndex, 1)
        engine.start()
        engine.onReset()
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.sessionIndex, 1)
    }

    func testCompletionIsDetectedWithoutSleeping() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let engine = makeEngine(clock: clock)
        var completionCount = 0
        engine.onPhaseCompleted = { completionCount += 1 }

        engine.start()
        clock.now = clock.now.addingTimeInterval(121)
        engine.recomputeRemaining()
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.status, .running)

        engine.checkForCompletion()
        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(completionCount, 1)
    }

    func testSkipLandsIdleAndStartNextLandsRunningOnTheNextPhase() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let engine = makeEngine(clock: clock)

        engine.onSkip()
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.remainingSeconds, 60)

        let anotherEngine = makeEngine(clock: clock)
        anotherEngine.onStartNext()
        XCTAssertEqual(anotherEngine.phase, .shortBreak)
        XCTAssertEqual(anotherEngine.status, .running)
        XCTAssertEqual(anotherEngine.remainingSeconds, 60)
    }

    func testInitRestoresExpiredRunningSnapshotAsComplete() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = FakeDateProvider(now: now)
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .focus,
            status: .running,
            sessionIndex: 2,
            endDate: now.addingTimeInterval(-1),
            pausedRemaining: nil
        ))

        let engine = makeEngine(clock: clock, store: store)

        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.sessionIndex, 2)
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    func testInitExpiredSnapshotInvokesCompletionCallback() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = FakeDateProvider(now: now)
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .focus,
            status: .running,
            sessionIndex: 2,
            endDate: now.addingTimeInterval(-1),
            pausedRemaining: nil
        ))
        var completionCount = 0

        let engine = TimerEngine(
            durationProvider: TestDurationProvider(),
            dateProvider: clock,
            persister: store,
            onPhaseCompleted: { completionCount += 1 }
        )

        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(completionCount, 1)
    }

    func testInitExpiredSnapshotRespectsDisabledAutoAdvance() async {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = FakeDateProvider(now: now)
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .shortBreak,
            status: .running,
            sessionIndex: 2,
            endDate: now.addingTimeInterval(-1),
            pausedRemaining: nil
        ))

        let engine = TimerEngine(
            durationProvider: TestDurationProvider(),
            dateProvider: clock,
            persister: store,
            autoStartNext: false
        )

        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(engine.phase, .shortBreak)
        try? await Task.sleep(for: .seconds(1.6))
        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(engine.phase, .shortBreak)
    }

    func testInitRestoresPausedAndIdleSnapshots() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let pausedStore = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .shortBreak,
            status: .paused,
            sessionIndex: 3,
            endDate: nil,
            pausedRemaining: 42
        ))
        let pausedEngine = makeEngine(clock: clock, store: pausedStore)
        XCTAssertEqual(pausedEngine.status, .paused)
        XCTAssertEqual(pausedEngine.phase, .shortBreak)
        XCTAssertEqual(pausedEngine.sessionIndex, 3)
        XCTAssertEqual(pausedEngine.remainingSeconds, 42)

        let idleStore = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .longBreak,
            status: .idle,
            sessionIndex: 4,
            endDate: nil,
            pausedRemaining: 180
        ))
        let idleEngine = makeEngine(clock: clock, store: idleStore)
        XCTAssertEqual(idleEngine.status, .idle)
        XCTAssertEqual(idleEngine.phase, .longBreak)
        XCTAssertEqual(idleEngine.sessionIndex, 4)
        XCTAssertEqual(idleEngine.remainingSeconds, 180)
    }

    func testAutoAdvanceGuardsAndSuccessPath() async {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        let disabledClock = FakeDateProvider(now: now)
        let disabledEngine = makeEngine(clock: disabledClock)
        disabledEngine.autoStartNext = false
        disabledEngine.start()
        disabledClock.now = now.addingTimeInterval(121)
        disabledEngine.recomputeRemaining()
        disabledEngine.checkForCompletion()
        try? await Task.sleep(for: .seconds(1.6))
        XCTAssertEqual(disabledEngine.status, .complete)

        let longBreakClock = FakeDateProvider(now: now)
        let longBreakStore = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .longBreak,
            status: .running,
            sessionIndex: 4,
            endDate: now.addingTimeInterval(-1),
            pausedRemaining: nil
        ))
        let longBreakEngine = makeEngine(clock: longBreakClock, store: longBreakStore)
        try? await Task.sleep(for: .seconds(1.6))
        XCTAssertEqual(longBreakEngine.status, .complete)
        XCTAssertEqual(longBreakEngine.phase, .longBreak)

        let enabledClock = FakeDateProvider(now: now)
        let enabledEngine = makeEngine(clock: enabledClock)
        enabledEngine.start()
        enabledClock.now = now.addingTimeInterval(121)
        enabledEngine.recomputeRemaining()
        enabledEngine.checkForCompletion()
        try? await Task.sleep(for: .seconds(1.6))
        XCTAssertEqual(enabledEngine.status, .running)
        XCTAssertEqual(enabledEngine.phase, .shortBreak)
        XCTAssertEqual(enabledEngine.remainingSeconds, 60)
    }

    private func makeEngine(clock: FakeDateProvider, store: RecordingTimerStateStore = RecordingTimerStateStore()) -> TimerEngine {
        TimerEngine(durationProvider: TestDurationProvider(), dateProvider: clock, persister: store)
    }
}

private final class FakeDateProvider: DateProviding {
    var now: Date
    init(now: Date) { self.now = now }
}

private struct TestDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int {
        switch phase { case .focus: 120; case .shortBreak: 60; case .longBreak: 180 }
    }
}

private final class RecordingTimerStateStore: TimerStatePersisting {
    var snapshot: TimerSnapshot?
    var latest: TimerSnapshot? { snapshot }
    init(snapshot: TimerSnapshot? = nil) { self.snapshot = snapshot }
    func load() -> TimerSnapshot? { snapshot }
    func save(_ snapshot: TimerSnapshot) { self.snapshot = snapshot }
}
