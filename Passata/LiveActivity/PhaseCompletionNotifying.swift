import Foundation
import UserNotifications

protocol PhaseCompletionNotifying {
    nonisolated func scheduleChain(_ boundaries: [PhaseBoundary]) async
    nonisolated func cancelPending() async
}

nonisolated struct SystemPhaseCompletionNotifier: PhaseCompletionNotifying {
    private let notificationIdentifiers = (0..<16).map { "phase-completion-\($0)" }
    private let center: any UserNotificationScheduling

    nonisolated init(center: any UserNotificationScheduling = SystemUserNotificationCenter()) {
        self.center = center
    }

    func scheduleChain(_ boundaries: [PhaseBoundary]) async {
        center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
        guard !boundaries.isEmpty else { return }
        let status = await center.authorizationStatus()
        if status == .notDetermined {
            guard (try? await center.requestAuthorization()) == true else { return }
        } else if status == .denied {
            return
        }

        for (index, boundary) in boundaries.prefix(notificationIdentifiers.count).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = title(for: boundary.phase)
            content.body = body(for: boundary.phase)
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: boundary.phaseEnd
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifiers[index],
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelPending() async {
        center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
    }

    private func title(for phase: Phase) -> String {
        switch phase {
        case .focus: "Focus session complete"
        case .shortBreak, .longBreak: "Break complete"
        }
    }

    private func body(for phase: Phase) -> String {
        switch phase {
        case .focus: "Time for a break."
        case .shortBreak, .longBreak: "Ready for your next focus session."
        }
    }
}
