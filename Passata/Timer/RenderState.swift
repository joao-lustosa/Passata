import Foundation

enum RenderState: Codable, Hashable {
    case running(phaseStart: Date, phaseEnd: Date)
    case idle(phaseDurationSeconds: Int)
    case paused(remainingSeconds: Int, phaseDurationSeconds: Int)
    case complete

    var staticProgress: Double {
        switch self {
        case .complete: 1
        case .idle: 0
        case let .paused(remaining, duration):
            duration > 0 ? 1 - Double(remaining) / Double(duration) : 0
        case .running: 0
        }
    }
}
