import Testing
@testable import Passata

@Test(arguments: [
    (Phase.focus, 1, 0),
    (Phase.focus, 3, 2),
    (Phase.shortBreak, 3, 3),
    (Phase.longBreak, 4, 4)
])
@MainActor
func sessionDotFillCountMatchesPhaseProgress(phase: Phase, sessionIndex: Int, expectedCount: Int) {
    #expect(phase.filledSessionCount(sessionIndex: sessionIndex) == expectedCount)
}
