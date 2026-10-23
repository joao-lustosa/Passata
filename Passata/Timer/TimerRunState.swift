import Foundation

enum TimerRunState: Equatable {
    case idle
    case running(phaseDuration: Int, endDate: Date)
    case paused(phaseDuration: Int, remaining: TimeInterval)
    case complete
}

extension TimerRunState {
    /// Converts the flat persisted snapshot into a legal state, falling back to idle
    /// when a running deadline or paused remaining time is missing.
    init(status: RunStatus, endDate: Date?, pausedRemaining: TimeInterval?, phaseDuration: Int) {
        switch (status, endDate, pausedRemaining) {
        case (.running, let endDate?, _): self = .running(phaseDuration: phaseDuration, endDate: endDate)
        case (.paused, _, let remaining?): self = .paused(phaseDuration: phaseDuration, remaining: remaining)
        case (.complete, _, _): self = .complete
        default: self = .idle
        }
    }

    var snapshotFields: (status: RunStatus, endDate: Date?, pausedRemaining: TimeInterval?, phaseDuration: Int?) {
        switch self {
        case .idle: (.idle, nil, nil, nil)
        case .running(let phaseDuration, let endDate): (.running, endDate, nil, phaseDuration)
        case .paused(let phaseDuration, let remaining): (.paused, nil, remaining, phaseDuration)
        case .complete: (.complete, nil, nil, nil)
        }
    }
}
