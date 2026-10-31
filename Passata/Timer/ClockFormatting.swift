import Foundation

extension Int {
    var asClockString: String {
        let seconds = Swift.max(0, self)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var asDurationSettingLabel: String {
        let seconds = Swift.max(0, self)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        guard remainingSeconds != 0 else { return "\(minutes) min" }
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }

    var asDurationInputString: String {
        let seconds = Swift.max(0, self)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        guard remainingSeconds != 0 else { return String(minutes) }
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}
