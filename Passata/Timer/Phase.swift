enum Phase: String, Codable, CaseIterable {
    case focus
    case shortBreak
    case longBreak
}

extension Phase {
    var displayName: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    func next(sessionIndex: Int, sessionsPerCycle: Int) -> (phase: Phase, sessionIndex: Int) {
        switch self {
        case .focus:
            return sessionIndex >= sessionsPerCycle ? (.longBreak, sessionIndex) : (.shortBreak, sessionIndex)
        case .shortBreak:
            return (.focus, sessionIndex + 1)
        case .longBreak:
            return (.focus, 1)
        }
    }
}
