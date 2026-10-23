import Foundation
import UserNotifications
import XCTest
@testable import Passata

@MainActor
final class SystemPhaseCompletionNotifierTests: XCTestCase {
    private let deadline = Date(timeIntervalSinceReferenceDate: 2_000_000)

    func testUndeterminedAuthorizationGrantedSchedulesNotification() async throws {
        let center = FakeUserNotificationScheduling()
        center.status = .notDetermined
        let notifier = SystemPhaseCompletionNotifier(center: center)

        await schedule(notifier, at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertEqual(center.addedRequests.count, 1)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(request.identifier, "phase-completion-0")
        XCTAssertEqual(request.content.title, "Focus session complete")
        XCTAssertEqual(request.content.body, "Time for a break.")
        XCTAssertNotNil(request.content.sound)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents, Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: deadline))
    }

    func testUndeterminedAuthorizationRefusedDoesNotSchedule() async {
        let center = FakeUserNotificationScheduling()
        center.status = .notDetermined
        center.requestAuthorizationResult = .success(false)

        await schedule(SystemPhaseCompletionNotifier(center: center), at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testAuthorizationErrorDoesNotSchedule() async {
        let center = FakeUserNotificationScheduling()
        center.status = .notDetermined
        center.requestAuthorizationResult = .failure(TestError.unavailable)

        await schedule(SystemPhaseCompletionNotifier(center: center), at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testDeniedAuthorizationDoesNotRequestPermissionOrSchedule() async {
        let center = FakeUserNotificationScheduling()
        center.status = .denied

        await schedule(SystemPhaseCompletionNotifier(center: center), at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testAuthorizedSchedulesBreakWithoutRequestingPermission() async throws {
        let center = FakeUserNotificationScheduling()

        await schedule(SystemPhaseCompletionNotifier(center: center), at: deadline, phase: .shortBreak)

        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertEqual(center.addedRequests.count, 1)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(request.identifier, "phase-completion-0")
        XCTAssertEqual(request.content.title, "Break complete")
        XCTAssertEqual(request.content.body, "Ready for your next focus session.")
    }

    func testAddErrorIsSwallowedAndLaterSchedulingStillWorks() async {
        let center = FakeUserNotificationScheduling()
        center.addResult = .failure(TestError.unavailable)
        let notifier = SystemPhaseCompletionNotifier(center: center)

        await schedule(notifier, at: deadline, phase: .focus)
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, "phase-completion-0")
        center.addResult = .success(())
        await schedule(notifier, at: deadline.addingTimeInterval(60), phase: .longBreak)
        XCTAssertEqual(center.addedRequests.count, 2)
        XCTAssertEqual(center.addedRequests.last?.content.title, "Break complete")
        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
    }

    func testCancelRemovesOnlyPhaseCompletionIdentifier() async {
        let center = FakeUserNotificationScheduling()

        await SystemPhaseCompletionNotifier(center: center).cancelPending()

        XCTAssertEqual(center.removedIdentifiers, [(0..<16).map { "phase-completion-\($0)" }])
        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testSchedulesAnOrderedChainUsingAtMostSixteenStableIdentifiers() async throws {
        let center = FakeUserNotificationScheduling()
        let notifier = SystemPhaseCompletionNotifier(center: center)
        let boundaries = (0..<18).map { index in
            PhaseBoundary(
                phase: index.isMultiple(of: 2) ? .focus : .shortBreak,
                sessionIndex: 1,
                phaseEnd: deadline.addingTimeInterval(TimeInterval(index * 60))
            )
        }

        await notifier.scheduleChain(boundaries)

        XCTAssertEqual(center.addedRequests.count, 16)
        XCTAssertEqual(center.addedRequests.map(\.identifier), (0..<16).map { "phase-completion-\($0)" })
        let firstTrigger = try XCTUnwrap(center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger)
        let secondTrigger = try XCTUnwrap(center.addedRequests[1].trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(firstTrigger.dateComponents, Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: deadline))
        XCTAssertEqual(secondTrigger.dateComponents, Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: deadline.addingTimeInterval(60)))
        XCTAssertEqual(center.addedRequests.map(\.content.title), Array(0..<16).map {
            $0.isMultiple(of: 2) ? "Focus session complete" : "Break complete"
        })
    }

    private func schedule(_ notifier: SystemPhaseCompletionNotifier, at deadline: Date, phase: Phase) async {
        await notifier.scheduleChain([PhaseBoundary(phase: phase, sessionIndex: 1, phaseEnd: deadline)])
    }

    private enum TestError: Error { case unavailable }
}

nonisolated private final class FakeUserNotificationScheduling: UserNotificationScheduling {
    var status: UNAuthorizationStatus = .authorized
    var requestAuthorizationResult: Result<Bool, Error> = .success(true)
    var addResult: Result<Void, Error> = .success(())
    private(set) var requestAuthorizationCallCount = 0
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        return try requestAuthorizationResult.get()
    }
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        try addResult.get()
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }
}
