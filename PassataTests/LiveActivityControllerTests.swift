import ActivityKit
import Foundation
import XCTest
@testable import Passata

@MainActor
final class LiveActivityControllerTests: XCTestCase {
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
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for the actor event consumer")
    }
}

@MainActor
final class PhaseCompletionControllerTests: XCTestCase {
    func testEveryTransitionKindMapsToTheNotificationDecisionTable() async {
        let notifier = RecordingPhaseCompletionNotifier()
        let controller = PhaseCompletionController(notifier: notifier)
        let running = RenderState.running(
            phaseStart: Date(timeIntervalSinceReferenceDate: 100),
            phaseEnd: Date(timeIntervalSinceReferenceDate: 220)
        )
        let staticRender = RenderState.paused(remainingSeconds: 50, phaseDurationSeconds: 120)

        controller.submit(phase: .focus, sessionIndex: 1, render: running, kind: .started)
        controller.submit(phase: .focus, sessionIndex: 1, render: running, kind: .resumed)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: running, kind: .startedNext)
        await waitUntil { notifier.snapshot().scheduleCount == 3 }
        XCTAssertEqual(notifier.snapshot().scheduledPhases, [.focus, .focus, .shortBreak])

        controller.submit(phase: .focus, sessionIndex: 1, render: staticRender, kind: .paused)
        controller.submit(phase: .focus, sessionIndex: 1, render: staticRender, kind: .reset)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: .idle(phaseDurationSeconds: 60), kind: .skipped)
        controller.submit(phase: .shortBreak, sessionIndex: 1, render: .complete, kind: .completed)
        await waitUntil { notifier.snapshot().cancelCount == 4 }
        XCTAssertEqual(notifier.snapshot().cancelCount, 4)
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for the actor event consumer")
    }
}

private final class RecordingLiveActivityPublisher: LiveActivityPublishing {
    struct Snapshot {
        let requestCount: Int
        let updateCount: Int
        let endCount: Int
        let actions: [String]
    }

    private let lock = NSLock()
    private(set) var requestCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var active: Bool
    private(set) var actions: [String] = []

    init(active: Bool = false) {
        self.active = active
    }

    func setActive(_ value: Bool) {
        lock.withLock { active = value }
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(requestCount: requestCount, updateCount: updateCount, endCount: endCount, actions: actions)
        }
    }

    func hasActiveActivity() async -> Bool {
        lock.withLock { active }
    }

    func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws {
        lock.withLock {
            requestCount += 1
            actions.append("request")
            active = true
        }
    }

    func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async {
        lock.withLock {
            updateCount += 1
            actions.append("update")
        }
    }

    func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async {
        lock.withLock {
            endCount += 1
            actions.append("end")
            active = false
        }
    }
}

private final class RecordingPhaseCompletionNotifier: PhaseCompletionNotifying {
    struct Snapshot {
        let scheduleCount: Int
        let cancelCount: Int
        let scheduledPhases: [Phase]
    }

    private let lock = NSLock()
    private(set) var scheduleCount = 0
    private(set) var cancelCount = 0
    private(set) var scheduledPhases: [Phase] = []

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(scheduleCount: scheduleCount, cancelCount: cancelCount, scheduledPhases: scheduledPhases)
        }
    }

    func schedule(at phaseEnd: Date, phase: Phase) async {
        lock.withLock {
            scheduleCount += 1
            scheduledPhases.append(phase)
        }
    }

    func cancelPending() async {
        lock.withLock { cancelCount += 1 }
    }
}
