enum ResetControlAction: Equatable {
    case disabled
    case resetPhase
    case restartCycle

    func perform(on engine: TimerEngine) {
        switch self {
        case .disabled:
            break
        case .resetPhase:
            engine.onReset()
        case .restartCycle:
            engine.restartCycle()
        }
    }
}

enum ResetControlRule {
    static func action(for phase: Phase, sessionIndex: Int, status: RunStatus) -> ResetControlAction {
        if status == .idle, phase == .focus, sessionIndex == 1 {
            return .disabled
        }
        return status == .idle ? .restartCycle : .resetPhase
    }

    static func primaryLabel(for status: RunStatus) -> String {
        switch status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .complete: ""
        }
    }

    static func requiresRestartCycleConfirmation(for status: RunStatus) -> Bool {
        status == .running || status == .paused
    }

    static func accessibilityHint(for action: ResetControlAction) -> String {
        switch action {
        case .disabled:
            "Reset is unavailable at the start of Focus 1."
        case .resetPhase:
            "Restarts the current phase and stops the timer."
        case .restartCycle:
            "Returns to Focus 1 and stops the timer."
        }
    }
}
