import ActivityKit
import Foundation

protocol LiveActivityPublishing {
    nonisolated func hasActiveActivity() async -> Bool
    nonisolated func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws
    nonisolated func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async
    nonisolated func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async
}

extension LiveActivityPublishing {
    nonisolated func endImmediately(_ content: PassataActivityAttributes.ContentState?) async {
        await end(content, dismissalPolicy: .immediate)
    }
}

// Activity's async update/end are treated as @concurrent on import and Activity itself isn't
// Sendable -- an SDK annotation gap, not something we control. Overlapping calls from
// LiveActivityController's two task origins are possible and already accepted as benign
// (see PassataApp's launch reconciliation); this asserts ActivityKit's own API tolerates
// concurrent invocation by design, not that we've serialized access to it. This is an
// inference about the framework's contract. Revisit if ActivityKit ships the annotation.
extension Activity: @retroactive @unchecked Sendable {}

nonisolated final class SystemLiveActivityPublisher: LiveActivityPublishing {
    private let lock = NSLock()
    private var currentActivity: Activity<PassataActivityAttributes>?

    nonisolated init() {}

    func hasActiveActivity() async -> Bool {
        guard let found = Activity<PassataActivityAttributes>.activities.first else { return false }
        lock.withLock { currentActivity = found }
        return true
    }

    func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws {
        let activity = try Activity<PassataActivityAttributes>.request(
            attributes: PassataActivityAttributes(),
            content: ActivityContent(state: content, staleDate: staleDate)
        )
        lock.withLock { currentActivity = activity }
    }

    func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async {
        let activity = lock.withLock { currentActivity }
        await activity?.update(ActivityContent(state: content, staleDate: staleDate))
    }

    func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async {
        let activity = lock.withLock { currentActivity }
        await activity?.end(
            content.map { ActivityContent(state: $0, staleDate: nil) },
            dismissalPolicy: dismissalPolicy
        )
        lock.withLock { currentActivity = nil }
    }
}
