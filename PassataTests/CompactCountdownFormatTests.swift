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

@Test(arguments: [
    (0, "0:00"),
    (65, "1:05"),
    (299, "4:59"),
    (1_500, "25:00"),
    (3_600, "60:00"),
    (-1, "0:00")
])
@MainActor
func integerClockFormatting(seconds: Int, expected: String) {
    #expect(seconds.asClockString == expected)
}

@Test(arguments: [
    (0, "0"),
    (1, "1"),
    (59, "1"),
    (60, "1"),
    (61, "2"),
    (-1, "0")
])
@MainActor
func limitedWidthIdleCountdownRoundsUpToWholeMinutes(seconds: Int, expected: String) {
    let label = CompactCountdownFormat.limitedWidthStaticLabel(for: .idle(phaseDurationSeconds: seconds))

    #expect(label == expected)
}

@Test(arguments: [
    (0, "0"),
    (1, "1"),
    (59, "1"),
    (60, "1"),
    (61, "2"),
    (-1, "0")
])
@MainActor
func limitedWidthPausedCountdownRoundsUpToWholeMinutes(seconds: Int, expected: String) {
    let render = RenderState.paused(remainingSeconds: seconds, phaseDurationSeconds: 120)
    let label = CompactCountdownFormat.limitedWidthStaticLabel(for: render)

    #expect(label == expected)
}

@Test
@MainActor
func limitedWidthCompletedCountdownShowsZero() {
    #expect(CompactCountdownFormat.limitedWidthStaticLabel(for: .complete) == "0")
}
