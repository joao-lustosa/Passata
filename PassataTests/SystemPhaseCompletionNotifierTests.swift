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

        await notifier.schedule(at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertEqual(center.addedRequests.count, 1)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(request.identifier, "phase-completion")
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

        await SystemPhaseCompletionNotifier(center: center).schedule(at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testAuthorizationErrorDoesNotSchedule() async {
        let center = FakeUserNotificationScheduling()
        center.status = .notDetermined
        center.requestAuthorizationResult = .failure(TestError.unavailable)

        await SystemPhaseCompletionNotifier(center: center).schedule(at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testDeniedAuthorizationDoesNotRequestPermissionOrSchedule() async {
        let center = FakeUserNotificationScheduling()
        center.status = .denied

        await SystemPhaseCompletionNotifier(center: center).schedule(at: deadline, phase: .focus)

        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testAuthorizedSchedulesBreakWithoutRequestingPermission() async throws {
        let center = FakeUserNotificationScheduling()

        await SystemPhaseCompletionNotifier(center: center).schedule(at: deadline, phase: .shortBreak)

        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertEqual(center.addedRequests.count, 1)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(request.identifier, "phase-completion")
        XCTAssertEqual(request.content.title, "Break complete")
        XCTAssertEqual(request.content.body, "Ready for your next focus session.")
    }

    func testAddErrorIsSwallowedAndLaterSchedulingStillWorks() async {
        let center = FakeUserNotificationScheduling()
        center.addResult = .failure(TestError.unavailable)
        let notifier = SystemPhaseCompletionNotifier(center: center)

        await notifier.schedule(at: deadline, phase: .focus)
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, "phase-completion")
        center.addResult = .success(())
        await notifier.schedule(at: deadline.addingTimeInterval(60), phase: .longBreak)
        XCTAssertEqual(center.addedRequests.count, 2)
        XCTAssertEqual(center.addedRequests.last?.content.title, "Break complete")
        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
    }

    func testCancelRemovesOnlyPhaseCompletionIdentifier() async {
        let center = FakeUserNotificationScheduling()

        await SystemPhaseCompletionNotifier(center: center).cancelPending()

        XCTAssertEqual(center.removedIdentifiers, [["phase-completion"]])
        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    private enum TestError: Error { case unavailable }
}

private final class FakeUserNotificationScheduling: UserNotificationScheduling {
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
