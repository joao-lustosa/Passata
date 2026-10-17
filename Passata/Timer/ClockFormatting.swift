import Foundation

extension Int {
    var asClockString: String {
        let seconds = Swift.max(0, self)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
