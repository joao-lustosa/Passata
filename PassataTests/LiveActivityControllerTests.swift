#if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
import ActivityKit
#endif
import Foundation
import XCTest
@testable import Passata

#if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
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
private final class RecordingLiveActivityPublisher: LiveActivityPublishing {
    struct Publication: Equatable {
        let action: String
        let content: PassataActivityAttributes.ContentState?
        let staleDate: Date?
    }

    struct Snapshot {
        let requestCount: Int
        let updateCount: Int
        let endCount: Int
        let actions: [String]
        let publications: [Publication]
    }

    private let lock = NSLock()
    private(set) var requestCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var active: Bool
    private(set) var actions: [String] = []
    private var publications: [Publication] = []

    init(active: Bool = false) {
        self.active = active
    }

    func setActive(_ value: Bool) {
        lock.withLock { active = value }
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(requestCount: requestCount, updateCount: updateCount, endCount: endCount, actions: actions, publications: publications)
        }
    }

    func hasActiveActivity() async -> Bool {
        lock.withLock { active }
    }

    func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws {
        lock.withLock {
            requestCount += 1
            actions.append("request")
            publications.append(.init(action: "request", content: content, staleDate: staleDate))
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

private final class RecordingPhaseCompletionNotifier: PhaseCompletionNotifying {
    struct Snapshot {
        let scheduleCount: Int
        let cancelCount: Int
        let scheduledPhases: [Phase]
        let scheduledDeadlines: [Date]
    }

    private let lock = NSLock()
    private(set) var scheduleCount = 0
    private(set) var cancelCount = 0
    private(set) var scheduledPhases: [Phase] = []
    private var scheduledDeadlines: [Date] = []

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(scheduleCount: scheduleCount, cancelCount: cancelCount, scheduledPhases: scheduledPhases, scheduledDeadlines: scheduledDeadlines)
        }
    }

    func schedule(at phaseEnd: Date, phase: Phase) async {
        lock.withLock {
            scheduleCount += 1
            scheduledPhases.append(phase)
            scheduledDeadlines.append(phaseEnd)
        }
    }

    func cancelPending() async {
        lock.withLock { cancelCount += 1 }
    }
}
