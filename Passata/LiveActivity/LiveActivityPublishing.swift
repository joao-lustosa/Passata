import ActivityKit
import Foundation

protocol LiveActivityPublishing {
    func hasActiveActivity() async -> Bool
    nonisolated func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws
    func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async
    func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async
}

extension LiveActivityPublishing {
    func endImmediately(_ content: PassataActivityAttributes.ContentState?) async {
        await end(content, dismissalPolicy: .immediate)
    }
}

final class SystemLiveActivityPublisher: LiveActivityPublishing {
    private var currentActivity: Activity<PassataActivityAttributes>?

    func hasActiveActivity() async -> Bool {
        guard let found = Activity<PassataActivityAttributes>.activities.first else { return false }
        currentActivity = found
        return true
    }

    func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws {
        currentActivity = try Activity<PassataActivityAttributes>.request(
            attributes: PassataActivityAttributes(),
            content: ActivityContent(state: content, staleDate: staleDate)
        )
    }

    func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async {
        await currentActivity?.update(ActivityContent(state: content, staleDate: staleDate))
    }

    func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async {
        await currentActivity?.end(
            content.map { ActivityContent(state: $0, staleDate: nil) },
            dismissalPolicy: dismissalPolicy
        )
        currentActivity = nil
    }
}
