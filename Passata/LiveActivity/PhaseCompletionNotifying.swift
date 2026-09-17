import Foundation
import UserNotifications

protocol PhaseCompletionNotifying {
    func schedule(at phaseEnd: Date, phase: Phase) async
    func cancelPending() async
}

struct SystemPhaseCompletionNotifier: PhaseCompletionNotifying {
    private let notificationIdentifier = "phase-completion"
    private let center: any UserNotificationScheduling

    nonisolated init(center: any UserNotificationScheduling = SystemUserNotificationCenter()) {
        self.center = center
    }

    func schedule(at phaseEnd: Date, phase: Phase) async {
        let status = await center.authorizationStatus()
        if status == .notDetermined {
            guard (try? await center.requestAuthorization()) == true else { return }
        } else if status == .denied {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title(for: phase)
        content.body = body(for: phase)
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: phaseEnd
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelPending() async {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
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
