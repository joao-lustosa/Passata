import UserNotifications

/// Wired by SystemPhaseCompletionNotifier's default parameter, not the app root, preserving PhaseCompletionNotifying's public surface.
protocol UserNotificationScheduling {
    nonisolated func authorizationStatus() async -> UNAuthorizationStatus
    nonisolated func requestAuthorization() async throws -> Bool
    nonisolated func add(_ request: UNNotificationRequest) async throws
    nonisolated func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

/// Stateless forwarder that obtains the current center per call, avoiding init-time side effects.
nonisolated struct SystemUserNotificationCenter: UserNotificationScheduling {
    nonisolated init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
