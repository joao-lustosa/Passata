import ActivityKit
import Foundation

struct PassataActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: Phase
        var sessionIndex: Int
        var render: RenderState
    }
}

enum RenderState: Codable, Hashable {
    case running(phaseStart: Date, phaseEnd: Date)
    case idle(phaseDurationSeconds: Int)
    case paused(remainingSeconds: Int, phaseDurationSeconds: Int)
    case complete
}
