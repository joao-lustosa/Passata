import Foundation

struct TimerSnapshot: Codable {
    var phase: Phase
    var status: RunStatus
    var sessionIndex: Int
    var endDate: Date?
    var pausedRemaining: TimeInterval?
}
