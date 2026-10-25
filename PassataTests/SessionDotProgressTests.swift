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

@Test(arguments: [
    (1, 4, 4),
    (6, 4, 6)
])
@MainActor
func displayedSessionCountIncludesConfiguredCycleAndCurrentSession(
    sessionIndex: Int,
    sessionsPerCycle: Int,
    expectedCount: Int
) {
    #expect(Phase.displayedSessionCount(sessionIndex: sessionIndex, sessionsPerCycle: sessionsPerCycle) == expectedCount)
}
