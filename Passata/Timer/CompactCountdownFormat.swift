import SwiftUI

enum CompactCountdownFormat {
    static func timerStyle(countingDownIn interval: Range<Date>) -> SystemFormatStyle.Timer {
        .timer(countingDownIn: interval, showsHours: false, maxFieldCount: 2)
            .locale(Locale(identifier: "en_US_POSIX"))
    }
}
