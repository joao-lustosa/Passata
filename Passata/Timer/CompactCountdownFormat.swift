import SwiftUI

enum CompactCountdownFormat {
    static func timerStyle(countingDownIn interval: Range<Date>) -> SystemFormatStyle.Timer {
        .timer(countingDownIn: interval, showsHours: false, maxFieldCount: 2)
            .locale(Locale(identifier: "en_US_POSIX"))
    }

    static func limitedWidthStaticLabel(for render: RenderState) -> String? {
        switch render {
        case .running:
            nil
        case .idle(let durationSeconds):
            minutesLabel(for: durationSeconds)
        case .paused(let remainingSeconds, _):
            minutesLabel(for: remainingSeconds)
        case .complete:
            "0"
        }
    }

    private static func minutesLabel(for seconds: Int) -> String {
        let nonnegativeSeconds = max(0, seconds)
        let wholeMinutes = nonnegativeSeconds / 60
        let hasRemainder = nonnegativeSeconds % 60 == 0 ? 0 : 1
        return String(wholeMinutes + hasRemainder)
    }
}
