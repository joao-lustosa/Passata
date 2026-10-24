import Foundation
import SwiftUI
import Testing
@testable import Passata

@Test
@MainActor
func compactCountdownUsesShortNumericTimerFormat() {
    let phaseStart = Date(timeIntervalSince1970: 1_000)
    let phaseEnd = phaseStart.addingTimeInterval(25 * 60)
    let style = CompactCountdownFormat.timerStyle(countingDownIn: phaseStart..<phaseEnd)

    #expect(String(style.format(phaseStart).characters) == "25:00")
}

@Test
@MainActor
func limitedWidthCountdownUsesShortNumericTime() {
    let phaseStart = Date(timeIntervalSince1970: 1_000)
    let phaseEnd = phaseStart.addingTimeInterval(25 * 60)
    let style = CompactCountdownFormat.timerStyle(countingDownIn: phaseStart..<phaseEnd)

    #expect(String(style.format(phaseStart).characters) == "25:00")
}

@Test(arguments: [
    (0, "00:00"),
    (65, "01:05"),
    (3_600, "60:00"),
    (-1, "00:00")
])
@MainActor
func integerClockFormatting(seconds: Int, expected: String) {
    #expect(seconds.asClockString == expected)
}
