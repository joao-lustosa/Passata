import Foundation
import UserNotifications

protocol PhaseCompletionNotifying {
    func schedule(at phaseEnd: Date, phase: Phase) async
    func cancelPending() async
}

struct SystemPhaseCompletionNotifier: PhaseCompletionNotifying {
    private let notificationIdentifier = "phase-completion"

    func schedule(at phaseEnd: Date, phase: Phase) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        } else if settings.authorizationStatus == .denied {
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
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
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
