import Foundation

enum TimerRunState: Equatable {
    case idle
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case complete
}

extension TimerRunState {
    /// Converts the flat persisted snapshot into a legal state, falling back to idle
    /// when a running deadline or paused remaining time is missing.
    init(status: RunStatus, endDate: Date?, pausedRemaining: TimeInterval?) {
        switch (status, endDate, pausedRemaining) {
        case (.running, let endDate?, _): self = .running(endDate: endDate)
        case (.paused, _, let remaining?): self = .paused(remaining: remaining)
        case (.complete, _, _): self = .complete
        default: self = .idle
        }
    }

    var snapshotFields: (status: RunStatus, endDate: Date?, pausedRemaining: TimeInterval?) {
        switch self {
        case .idle: (.idle, nil, nil)
        case .running(let endDate): (.running, endDate, nil)
        case .paused(let remaining): (.paused, nil, remaining)
        case .complete: (.complete, nil, nil)
        }
    }
}
