import Foundation

// New non-Optional fields need a decodeIfPresent ?? default decoder, like TimerSettings.
struct TimerSnapshot: Codable {
    var phase: Phase
    var status: RunStatus
    var sessionIndex: Int
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var phaseDuration: Int? = nil
}
