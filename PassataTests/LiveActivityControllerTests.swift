#if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
import ActivityKit
#endif
import Foundation
import XCTest
@testable import Passata

#if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
@MainActor
final class LiveActivityControllerTests: XCTestCase {
    func testSkipThenStartUpdatesExistingActivityWithRunningDates() async {
        let publisher = RecordingLiveActivityPublisher()
        let controller = LiveActivityController(publisher: publisher)
        let clock = LiveActivityTestClock()
        let engine = TimerEngine(
            durationProvider: LiveActivityTestDurations(),
            dateProvider: clock,
            persister: LiveActivityTestStateStore(),
            autoStartNext: false,
            onStateChange: { phase, sessionIndex, render, kind in
                controller.submit(phase: phase, sessionIndex: sessionIndex, render: render, kind: kind)
            }
        )

        engine.start()
        await waitUntil { publisher.snapshot().publications.count == 1 }
        engine.onSkip()
        engine.onSkip()
        engine.start()
        await waitUntil { publisher.snapshot().publications.count == 4 }
        guard publisher.snapshot().publications.count == 4 else {
            XCTFail("The activity must receive Start, both Skips, and the second Start.")
            return
        }

        let focusStart = clock.now
        let focusEnd = focusStart.addingTimeInterval(1500)
        let running = RenderState.running(phaseStart: focusStart, phaseEnd: focusEnd)
        XCTAssertEqual(engine.sessionIndex, 2)
        XCTAssertEqual(engine.currentRenderState, running)
        XCTAssertEqual(publisher.snapshot().requestCount, 1, "Start must reuse the activity displaying the skipped phase.")
        XCTAssertEqual(publisher.snapshot().publications[1], .init(
            action: "update",
            content: .init(phase: .shortBreak, sessionIndex: 1, sessionsPerCycle: 4,
                           render: .idle(phaseDurationSeconds: 300)),
            staleDate: nil
        ))
        XCTAssertEqual(publisher.snapshot().publications[2], .init(
            action: "update",
            content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4,
                           render: .idle(phaseDurationSeconds: 1500)),
            staleDate: nil
        ))
        XCTAssertEqual(publisher.snapshot().publications.last, .init(
            action: "update",
            content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4, render: running),
            staleDate: focusEnd
        ))

        clock.now = focusStart.addingTimeInterval(23)
        engine.recomputeRemaining()
        XCTAssertEqual(engine.remainingSeconds, 1477)
        XCTAssertEqual(engine.currentRenderState, running, "The payload must retain dates so the host can count down.")
        engine.pause()
        clock.now = clock.now.addingTimeInterval(14)
        engine.resume()
        engine.onReset()
        await waitUntil { publisher.snapshot().publications.count == 7 }
        let payloads = publisher.snapshot().publications
        guard payloads.count == 7 else {
            XCTFail("The activity must receive Pause, Resume, and Reset.")
            return
        }
        XCTAssertEqual(payloads[4], .init(
            action: "update",
            content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4,
                           render: .paused(remainingSeconds: 1477, phaseDurationSeconds: 1500)),
            staleDate: nil
        ))
        XCTAssertEqual(payloads[5], .init(
            action: "update",
            content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4,
                           render: .running(phaseStart: focusStart.addingTimeInterval(14),
                                            phaseEnd: focusEnd.addingTimeInterval(14))),
            staleDate: focusEnd.addingTimeInterval(14)
        ))
        XCTAssertEqual(payloads[6], .init(
            action: "end",
            content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4,
                           render: .idle(phaseDurationSeconds: 1500)),
            staleDate: nil
        ))

        engine.start()
        await waitUntil { publisher.snapshot().publications.count == 8 }
        XCTAssertEqual(publisher.snapshot().requestCount, 2, "Reset ends the old activity, so the next Start requests a new one.")
        XCTAssertEqual(publisher.snapshot().publications.last, .init(
            action: "request",
            content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4,
                           render: .running(phaseStart: clock.now, phaseEnd: clock.now.addingTimeInterval(1500))),
            staleDate: clock.now.addingTimeInterval(1500)
        ))
    }

    func testRequestFailureDoesNotStopQueuedPausedEvent() async {
        let publisher = RecordingLiveActivityPublisher(failNextRequest: true)
        let controller = LiveActivityController(publisher: publisher)
        let deadline = Date(timeIntervalSinceReferenceDate: 220)
        let running = RenderState.running(phaseStart: Date(timeIntervalSinceReferenceDate: 100), phaseEnd: deadline)
        let paused = RenderState.paused(remainingSeconds: 75, phaseDurationSeconds: 120)

        controller.submit(phase: .focus, sessionIndex: 2, render: running, kind: .started)
        controller.submit(phase: .focus, sessionIndex: 2, render: paused, kind: .paused)
        await waitUntil { publisher.snapshot().updateCount == 1 }

        XCTAssertEqual(publisher.snapshot().requestFailureCount, 1)
        let active = await publisher.hasActiveActivity()
        XCTAssertFalse(active)
        XCTAssertEqual(publisher.snapshot().publications, [
            .init(action: "request", content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4, render: running), staleDate: deadline),
            .init(action: "update", content: .init(phase: .focus, sessionIndex: 2, sessionsPerCycle: 4, render: paused), staleDate: nil)
        ])
    }

    func testReconcileRequestFailureAllowsLaterSubmittedRequest() async {
        let publisher = RecordingLiveActivityPublisher(failNextRequest: true)
        let controller = LiveActivityController(publisher: publisher)
        let deadline = Date(timeIntervalSinceReferenceDate: 480)
        let running = RenderState.running(phaseStart: Date(timeIntervalSinceReferenceDate: 300), phaseEnd: deadline)
        let content = PassataActivityAttributes.ContentState(phase: .longBreak, sessionIndex: 4, sessionsPerCycle: 4, render: running)

        await controller.reconcileOnLaunch(phase: .longBreak, sessionIndex: 4, status: .running, render: running)
        XCTAssertEqual(publisher.snapshot().requestFailureCount, 1)
        let activeAfterFailure = await publisher.hasActiveActivity()
        XCTAssertFalse(activeAfterFailure)

        controller.submit(phase: .longBreak, sessionIndex: 4, render: running, kind: .started)
        await waitUntil { publisher.snapshot().requestCount == 2 }
        let activeAfterRecovery = await publisher.hasActiveActivity()
        XCTAssertTrue(activeAfterRecovery)
        XCTAssertEqual(publisher.snapshot().requestFailureCount, 1)
        XCTAssertEqual(publisher.snapshot().publications, [
            .init(action: "request", content: content, staleDate: deadline),
            .init(action: "request", content: content, staleDate: deadline)
        ])
    }

    func testTransitionKindsMapToPublisherActionsInSubmissionOrder() async {
        let publisher = RecordingLiveActivityPublisher()
        let controller = LiveActivityController(publisher: publisher)
        let running = RenderState.running(
            phaseStart: Date(timeIntervalSinceReferenceDate: 100),
            phaseEnd: Date(timeIntervalSinceReferenceDate: 220)
        )
        let paused = RenderState.paused(remainingSeconds: 50, phaseDurationSeconds: 120)
        controller.submit(phase: .focus, sessionIndex: 1, render: running, kind: .started)
        await waitUntil { publisher.snapshot().requestCount == 1 }
        XCTAssertEqual(publisher.snapshot().requestCount, 1)

        controller.submit(phase: .focus, sessionIndex: 1, render: running, kind: .resumed)
        controller.submit(phase: .focus, sessionIndex: 1, render: paused, kind: .paused)
        controller.submit(phase: .focus, sessionIndex: 1, render: .complete, kind: .completed)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: .idle(phaseDurationSeconds: 60), kind: .skipped)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: running, kind: .startedNext)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: .idle(phaseDurationSeconds: 60), kind: .reset)

        await waitUntil {
            let snapshot = publisher.snapshot()
            return snapshot.updateCount == 5 && snapshot.endCount == 1
        }
        XCTAssertEqual(publisher.snapshot().updateCount, 5)
        XCTAssertEqual(publisher.snapshot().endCount, 1)
        XCTAssertEqual(
            publisher.snapshot().actions,
            ["request", "update", "update", "update", "update", "update", "end"]
        )
        let focusRunning = PassataActivityAttributes.ContentState(
            phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: running)
        let shortIdle = PassataActivityAttributes.ContentState(
            phase: .shortBreak, sessionIndex: 1, sessionsPerCycle: 4, render: .idle(phaseDurationSeconds: 60))
        let deadline = Date(timeIntervalSinceReferenceDate: 220)
        XCTAssertEqual(publisher.snapshot().publications, [
            .init(action: "request", content: focusRunning, staleDate: deadline),
            .init(action: "update", content: focusRunning, staleDate: deadline),
            .init(action: "update", content: .init(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: paused), staleDate: nil),
            .init(action: "update", content: .init(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .complete), staleDate: nil),
            .init(action: "update", content: shortIdle, staleDate: nil),
            .init(action: "update", content: .init(phase: .shortBreak, sessionIndex: 1, sessionsPerCycle: 4, render: running), staleDate: deadline),
            .init(action: "end", content: shortIdle, staleDate: nil)
        ])
    }

    func testReconcileOnLaunchUsesExistingActivityState() async {
        let publisher = RecordingLiveActivityPublisher(active: true)
        let controller = LiveActivityController(publisher: publisher)

        await controller.reconcileOnLaunch(
            phase: .focus,
            sessionIndex: 1,
            status: .idle,
            render: .idle(phaseDurationSeconds: 120)
        )
        await waitUntil { publisher.snapshot().endCount == 1 }

        publisher.setActive(true)
        await controller.reconcileOnLaunch(
            phase: .focus,
            sessionIndex: 1,
            status: .running,
            render: .running(
                phaseStart: Date(timeIntervalSinceReferenceDate: 100),
                phaseEnd: Date(timeIntervalSinceReferenceDate: 220)
            )
        )
        XCTAssertEqual(publisher.snapshot().updateCount, 1)
        XCTAssertEqual(publisher.snapshot().publications, [
            .init(action: "end", content: .init(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4,
                                             render: .idle(phaseDurationSeconds: 120)), staleDate: nil),
            .init(action: "update", content: .init(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4,
                                                render: .running(phaseStart: Date(timeIntervalSinceReferenceDate: 100),
                                                                 phaseEnd: Date(timeIntervalSinceReferenceDate: 220))),
                  staleDate: Date(timeIntervalSinceReferenceDate: 220))
        ])
    }

    func testReconcileWithoutActivityIgnoresIdleAndRequestsRunningPayload() async {
        let publisher = RecordingLiveActivityPublisher()
        let controller = LiveActivityController(publisher: publisher)
        await controller.reconcileOnLaunch(phase: .focus, sessionIndex: 1, status: .idle,
                                           render: .idle(phaseDurationSeconds: 120))
        XCTAssertEqual(publisher.snapshot().publications, [])

        let render = RenderState.running(phaseStart: Date(timeIntervalSinceReferenceDate: 300.25),
                                         phaseEnd: Date(timeIntervalSinceReferenceDate: 480.25))
        await controller.reconcileOnLaunch(phase: .longBreak, sessionIndex: 4, status: .running, render: render)
        XCTAssertEqual(publisher.snapshot().publications, [
            .init(action: "request", content: .init(phase: .longBreak, sessionIndex: 4, sessionsPerCycle: 4, render: render),
                  staleDate: Date(timeIntervalSinceReferenceDate: 480.25))
        ])
    }

}

#endif

@MainActor
final class PhaseCompletionControllerTests: XCTestCase {
    func testInterleavedTransitionsPreserveOrderAndIgnoreNonRunningStarts() async {
        let notifier = RecordingPhaseCompletionNotifier()
        let controller = PhaseCompletionController(notifier: notifier)
        let deadline = Date(timeIntervalSinceReferenceDate: 220)
        let running = RenderState.running(phaseStart: Date(timeIntervalSinceReferenceDate: 100), phaseEnd: deadline)
        let paused = RenderState.paused(remainingSeconds: 50, phaseDurationSeconds: 120)
        let idle = RenderState.idle(phaseDurationSeconds: 120)
        let transitions: [(TimerEngine.TransitionKind, RenderState)] = [
            (.started, running), (.paused, paused), (.resumed, running),
            (.reset, idle), (.startedNext, running), (.skipped, idle), (.completed, .complete)
        ]
        for (kind, render) in transitions {
            controller.submit(phase: .focus, sessionIndex: 1, render: render, kind: kind)
        }

        for kind: TimerEngine.TransitionKind in [.started, .resumed, .startedNext] {
            for render in [idle, paused, .complete] {
                controller.submit(phase: .focus, sessionIndex: 1, render: render, kind: kind)
            }
        }
        // A distinct trailing schedule proves all preceding no-op events were consumed.
        let finalDeadline = Date(timeIntervalSinceReferenceDate: 400)
        controller.submit(phase: .shortBreak, sessionIndex: 2,
                          render: .running(phaseStart: deadline, phaseEnd: finalDeadline), kind: .startedNext)
        await waitUntil { notifier.snapshot().scheduledDeadlines.last == finalDeadline }
        XCTAssertEqual(notifier.snapshot().actions, [
            .schedule(phase: .focus, deadline: deadline), .cancel,
            .schedule(phase: .focus, deadline: deadline), .cancel,
            .schedule(phase: .focus, deadline: deadline), .cancel, .cancel,
            .schedule(phase: .shortBreak, deadline: finalDeadline)
        ])
    }

    func testEveryTransitionKindMapsToTheNotificationDecisionTable() async {
        let notifier = RecordingPhaseCompletionNotifier()
        let controller = PhaseCompletionController(notifier: notifier)
        let running = RenderState.running(
            phaseStart: Date(timeIntervalSinceReferenceDate: 100),
            phaseEnd: Date(timeIntervalSinceReferenceDate: 220)
        )
        let staticRender = RenderState.paused(remainingSeconds: 50, phaseDurationSeconds: 120)
        let resumed = RenderState.running(phaseStart: Date(timeIntervalSinceReferenceDate: 160),
                                          phaseEnd: Date(timeIntervalSinceReferenceDate: 280))

        controller.submit(phase: .focus, sessionIndex: 1, render: running, kind: .started)
        controller.submit(phase: .focus, sessionIndex: 1, render: resumed, kind: .resumed)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: running, kind: .startedNext)
        await waitUntil { notifier.snapshot().scheduleCount == 3 }
        XCTAssertEqual(notifier.snapshot().scheduledPhases, [.focus, .focus, .shortBreak])
        XCTAssertEqual(notifier.snapshot().scheduledDeadlines, [220, 280, 220].map {
            Date(timeIntervalSinceReferenceDate: $0)
        })

        controller.submit(phase: .focus, sessionIndex: 1, render: staticRender, kind: .paused)
        controller.submit(phase: .focus, sessionIndex: 1, render: staticRender, kind: .reset)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: .idle(phaseDurationSeconds: 60), kind: .skipped)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: .complete, kind: .completed)
        await waitUntil { notifier.snapshot().cancelCount == 4 }
        XCTAssertEqual(notifier.snapshot().cancelCount, 4)
    }

}

@MainActor
private func waitUntil(_ condition: @escaping () -> Bool) async {
    for _ in 0..<100 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("Timed out waiting for the actor event consumer")
}

#if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
@MainActor
private final class LiveActivityTestClock: DateProviding {
    var now = Date(timeIntervalSinceReferenceDate: 100)
}

@MainActor
private struct LiveActivityTestDurations: DurationProviding {
    func duration(for phase: Phase) -> Int { PhaseDurations.classic.seconds(for: phase) }
}

@MainActor
private final class LiveActivityTestStateStore: TimerStatePersisting {
    func load() -> TimerSnapshot? { nil }
    func save(_ snapshot: TimerSnapshot) {}
}

// All mutable state is private and accessed only while holding lock.
nonisolated private final class RecordingLiveActivityPublisher: LiveActivityPublishing, @unchecked Sendable {
    struct Publication: Equatable {
        let action: String
        let content: PassataActivityAttributes.ContentState?
        let staleDate: Date?
    }

    struct Snapshot {
        let requestCount: Int
        let requestFailureCount: Int
        let updateCount: Int
        let endCount: Int
        let actions: [String]
        let publications: [Publication]
    }

    private let lock = NSLock()
    private var requestCount = 0
    private var updateCount = 0
    private var endCount = 0
    private var active: Bool
    private var actions: [String] = []
    private var publications: [Publication] = []
    private var failNextRequest: Bool
    private var requestFailureCount = 0
    private enum RequestError: Error { case unavailable }

    init(active: Bool = false, failNextRequest: Bool = false) {
        self.active = active
        self.failNextRequest = failNextRequest
    }

    func setActive(_ value: Bool) {
        lock.withLock { active = value }
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(requestCount: requestCount, requestFailureCount: requestFailureCount, updateCount: updateCount, endCount: endCount, actions: actions, publications: publications)
        }
    }

    func hasActiveActivity() async -> Bool {
        lock.withLock { active }
    }

    func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws {
        try lock.withLock {
            requestCount += 1
            actions.append("request")
            publications.append(.init(action: "request", content: content, staleDate: staleDate))
            if failNextRequest {
                failNextRequest = false
                requestFailureCount += 1
                throw RequestError.unavailable
            }
            active = true
        }
    }

    func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async {
        lock.withLock {
            updateCount += 1
            actions.append("update")
            publications.append(.init(action: "update", content: content, staleDate: staleDate))
        }
    }

    func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async {
        lock.withLock {
            endCount += 1
            actions.append("end")
            publications.append(.init(action: "end", content: content, staleDate: nil))
            active = false
        }
    }
}

#endif

// All mutable state is private and accessed only while holding lock.
nonisolated private final class RecordingPhaseCompletionNotifier: PhaseCompletionNotifying, @unchecked Sendable {
    enum Action: Equatable {
        case schedule(phase: Phase, deadline: Date)
        case cancel
    }

    struct Snapshot {
        let scheduleCount: Int
        let cancelCount: Int
        let scheduledPhases: [Phase]
        let scheduledDeadlines: [Date]
        let actions: [Action]
    }

    private let lock = NSLock()
    private var scheduleCount = 0
    private var cancelCount = 0
    private var scheduledPhases: [Phase] = []
    private var scheduledDeadlines: [Date] = []
    private var actions: [Action] = []

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(scheduleCount: scheduleCount, cancelCount: cancelCount, scheduledPhases: scheduledPhases, scheduledDeadlines: scheduledDeadlines, actions: actions)
        }
    }

    func schedule(at phaseEnd: Date, phase: Phase) async {
        lock.withLock {
            scheduleCount += 1
            scheduledPhases.append(phase)
            scheduledDeadlines.append(phaseEnd)
            actions.append(.schedule(phase: phase, deadline: phaseEnd))
        }
    }

    func cancelPending() async {
        lock.withLock {
            cancelCount += 1
            actions.append(.cancel)
        }
    }
}
