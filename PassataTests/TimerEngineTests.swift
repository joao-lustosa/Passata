import Foundation
import XCTest
@testable import Passata

@MainActor
final class TimerEngineTests: XCTestCase {
    func testCompletionCallbackAndTransitionAreEmittedExactlyOnce() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        var completions = 0
        var completedEvents = 0
        let engine = TimerEngine(
            durationProvider: TestDurationProvider(),
            dateProvider: clock,
            persister: RecordingTimerStateStore(),
            autoStartNext: false,
            onPhaseCompleted: { completions += 1 },
            onStateChange: { _, _, _, kind in
                if case .completed = kind { completedEvents += 1 }
            }
        )

        engine.start()
        clock.now = clock.now.addingTimeInterval(120)
        for _ in 0..<3 {
            engine.recomputeRemaining()
            engine.checkForCompletion()
        }

        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(completedEvents, 1)
    }

    func testManualTransitionsCancelPendingAutoAdvanceEvenIfAnotherPhaseCompletes() async {
        let actions: [(String, (TimerEngine) -> Void, Phase)] = [
            ("reset", { $0.onReset() }, .focus),
            ("skip", { $0.onSkip() }, .shortBreak),
            ("start next", { $0.onStartNext() }, .shortBreak)
        ]
        var engines: [TimerEngine] = []
        var unexpectedAdvances: [XCTestExpectation] = []

        for (name, action, expectedPhase) in actions {
            let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
            let engine = makeEngine(clock: clock)
            engine.start()
            clock.now = clock.now.addingTimeInterval(120)
            engine.checkForCompletion()
            await Task.yield()

            action(engine)
            XCTAssertEqual(engine.phase, expectedPhase, name)
            XCTAssertEqual(engine.sessionIndex, 1, name)
            engine.autoStartNext = false
            if engine.status == .idle { engine.start() }
            clock.now = clock.now.addingTimeInterval(180)
            engine.checkForCompletion()
            XCTAssertEqual(engine.status, .complete, name)

            // Returning to complete makes the old task's status guard pass;
            // only cancellation prevents it from advancing this newer completion.
            let unexpectedAdvance = expectation(description: "No stale auto-advance after " + name)
            unexpectedAdvance.isInverted = true
            engine.onStateChange = { _, _, _, kind in
                if case .startedNext = kind { unexpectedAdvance.fulfill() }
            }
            engines.append(engine)
            unexpectedAdvances.append(unexpectedAdvance)
        }

        await fulfillment(of: unexpectedAdvances, timeout: 1.8)
        for (engine, action) in zip(engines, actions) {
            XCTAssertEqual(engine.status, .complete, action.0)
            XCTAssertEqual(engine.phase, action.2, action.0)
            XCTAssertEqual(engine.sessionIndex, 1, action.0)
        }
    }

    func testEngineTraversesAFullFourSessionCycle() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let engine = makeEngine(clock: clock)
        let expected: [(Phase, Int, Int)] = [
            (.shortBreak, 1, 60), (.focus, 2, 120),
            (.shortBreak, 2, 60), (.focus, 3, 120),
            (.shortBreak, 3, 60), (.focus, 4, 120),
            (.longBreak, 4, 180), (.focus, 1, 120)
        ]

        for (index, step) in expected.enumerated() {
            if index.isMultiple(of: 2) { engine.onSkip() } else { engine.onStartNext() }
            XCTAssertEqual(engine.phase, step.0, "Transition \(index)")
            XCTAssertEqual(engine.sessionIndex, step.1, "Transition \(index)")
            XCTAssertEqual(engine.remainingSeconds, step.2, "Transition \(index)")
            XCTAssertEqual(engine.status, index.isMultiple(of: 2) ? .idle : .running)
        }
    }

    func testFractionalRemainingRoundsUpButPausedRenderTruncates() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let engine = makeEngine(clock: clock)
        engine.start()
        clock.now = clock.now.addingTimeInterval(30.25)
        engine.recomputeRemaining()
        XCTAssertEqual(engine.remainingSeconds, 90)

        engine.pause()
        XCTAssertEqual(engine.state, .paused(remaining: 89.75))
        XCTAssertEqual(engine.remainingSeconds, 90)
        XCTAssertEqual(engine.currentRenderState, .paused(remainingSeconds: 89, phaseDurationSeconds: 120))
        clock.now = clock.now.addingTimeInterval(500)
        engine.recomputeRemaining()
        XCTAssertEqual(engine.remainingSeconds, 90)
    }

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

    func testInitRestoresRunningSnapshotWithoutDeadlineAsIdle() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .shortBreak,
            status: .running,
            sessionIndex: 2,
            endDate: nil,
            pausedRemaining: 17
        ))

        let engine = makeEngine(clock: clock, store: store)

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.sessionIndex, 2)
        XCTAssertEqual(engine.remainingSeconds, 60)
        XCTAssertEqual(engine.currentRenderState, .idle(phaseDurationSeconds: 60))

        engine.start()
        XCTAssertEqual(store.latest?.status, .running)
        XCTAssertEqual(store.latest?.endDate, clock.now.addingTimeInterval(60))
        XCTAssertNil(store.latest?.pausedRemaining)
    }

    func testInitRestoresIdleDurationFromProviderIgnoringStaleSnapshotFields() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .longBreak,
            status: .idle,
            sessionIndex: 4,
            endDate: clock.now.addingTimeInterval(500),
            pausedRemaining: 17
        ))

        let engine = makeEngine(clock: clock, store: store)
        clock.now = clock.now.addingTimeInterval(1_000)
        engine.recomputeRemaining()
        engine.checkForCompletion()

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.remainingSeconds, 180)
        XCTAssertEqual(engine.currentRenderState, .idle(phaseDurationSeconds: 180))
    }

    func testInitRestoresPausedSnapshotWithoutRemainingTimeAsIdle() {
        let clock = FakeDateProvider(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .focus,
            status: .paused,
            sessionIndex: 3,
            endDate: nil,
            pausedRemaining: nil
        ))

        let engine = makeEngine(clock: clock, store: store)

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remainingSeconds, 120)
        XCTAssertEqual(engine.currentRenderState, .idle(phaseDurationSeconds: 120))
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

    func testInitExpiredSnapshotPublishesCompletedStateChange() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = FakeDateProvider(now: now)
        let store = RecordingTimerStateStore(snapshot: TimerSnapshot(
            phase: .focus,
            status: .running,
            sessionIndex: 2,
            endDate: now.addingTimeInterval(-1),
            pausedRemaining: nil
        ))
        var received: (Phase, Int, RenderState, TimerEngine.TransitionKind)?

        let engine = TimerEngine(
            durationProvider: TestDurationProvider(),
            dateProvider: clock,
            persister: store,
            autoStartNext: false,
            onStateChange: { phase, sessionIndex, render, kind in
                received = (phase, sessionIndex, render, kind)
            }
        )

        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(received?.0, .focus)
        XCTAssertEqual(received?.1, 2)
        if case .complete? = received?.2 {
            // Expected snapshot-restore render state.
        } else {
            XCTFail("expired snapshot should publish a complete render state")
        }
        if case .completed? = received?.3 {
            // Expected completion transition.
        } else {
            XCTFail("expired snapshot should publish a completed transition")
        }
    }

    func testStateChangeHookPublishesEachTransitionRenderState() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let clock = FakeDateProvider(now: now)
        var events: [(TimerEngine.TransitionKind, Phase, Int, RenderState)] = []
        let engine = TimerEngine(
            durationProvider: TestDurationProvider(),
            dateProvider: clock,
            persister: RecordingTimerStateStore(),
            autoStartNext: false,
            onStateChange: { phase, sessionIndex, render, kind in
                events.append((kind, phase, sessionIndex, render))
            }
        )

        engine.start()
        guard case let .running(phaseStart, phaseEnd) = events[0].3 else {
            return XCTFail("start should publish a running render state")
        }
        XCTAssertEqual(phaseStart, now)
        XCTAssertEqual(phaseEnd, now.addingTimeInterval(120))

        clock.now = now.addingTimeInterval(30)
        engine.pause()
        guard case let .paused(remaining, duration) = events[1].3 else {
            return XCTFail("pause should publish a paused render state")
        }
        XCTAssertEqual(remaining, 90)
        XCTAssertEqual(duration, 120)

        clock.now = now.addingTimeInterval(100)
        engine.resume()
        guard case let .running(resumedStart, resumedEnd) = events[2].3 else {
            return XCTFail("resume should publish a running render state")
        }
        XCTAssertEqual(resumedStart, now.addingTimeInterval(70))
        XCTAssertEqual(resumedEnd, now.addingTimeInterval(190))

        engine.onReset()
        guard case let .idle(durationAfterReset) = events[3].3 else {
            return XCTFail("reset should publish an idle render state")
        }
        XCTAssertEqual(durationAfterReset, 120)

        engine.onSkip()
        guard case let .idle(durationAfterSkip) = events[4].3 else {
            return XCTFail("skip should publish an idle render state")
        }
        XCTAssertEqual(durationAfterSkip, 60)

        engine.onStartNext()
        guard case let .running(nextStart, nextEnd) = events[5].3 else {
            return XCTFail("start-next should publish a running render state")
        }
        XCTAssertEqual(nextStart, clock.now)
        XCTAssertEqual(nextEnd, clock.now.addingTimeInterval(120))

        clock.now = nextEnd.addingTimeInterval(1)
        engine.checkForCompletion()
        guard case .complete = events[6].3 else {
            return XCTFail("completion should publish a complete render state")
        }
        let kinds = events.map { event in
            switch event.0 {
            case .started: "started"
            case .resumed: "resumed"
            case .paused: "paused"
            case .completed: "completed"
            case .skipped: "skipped"
            case .startedNext: "startedNext"
            case .reset: "reset"
            }
        }
        XCTAssertEqual(kinds, ["started", "paused", "resumed", "reset", "skipped", "startedNext", "completed"])
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
