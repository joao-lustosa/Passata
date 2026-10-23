import XCTest
@testable import Passata

final class ResetControlRuleTests: XCTestCase {
    func testResetIsDisabledOnlyAtTheStartOfFocusOne() {
        for phase in Phase.allCases {
            for sessionIndex in 1...TimerEngine.sessionsPerCycle {
                let action = ResetControlRule.action(for: phase, sessionIndex: sessionIndex, status: .idle)
                let shouldBeDisabled = phase == .focus && sessionIndex == 1
                XCTAssertEqual(action == .disabled, shouldBeDisabled, "\(phase), session \(sessionIndex)")
            }
        }
    }

    func testResetTapRestartsTheCycleOnlyWhenAnIdlePhaseIsAlreadyAtItsStart() {
        for phase in Phase.allCases where phase != .focus {
            for sessionIndex in 1...TimerEngine.sessionsPerCycle {
                XCTAssertEqual(
                    ResetControlRule.action(for: phase, sessionIndex: sessionIndex, status: .idle),
                    .restartCycle
                )
            }
        }
    }

    func testResetTapRestartsTheCurrentPhaseWhenItHasProgress() {
        for status: RunStatus in [.running, .paused, .complete] {
            for phase in Phase.allCases {
                for sessionIndex in 1...TimerEngine.sessionsPerCycle {
                    XCTAssertEqual(
                        ResetControlRule.action(for: phase, sessionIndex: sessionIndex, status: status),
                        .resetPhase
                    )
                }
            }
        }
    }

    func testRestartCycleConfirmationIsRequiredOnlyWhileRunningOrPaused() {
        XCTAssertFalse(ResetControlRule.requiresRestartCycleConfirmation(for: .idle))
        XCTAssertTrue(ResetControlRule.requiresRestartCycleConfirmation(for: .running))
        XCTAssertTrue(ResetControlRule.requiresRestartCycleConfirmation(for: .paused))
        XCTAssertFalse(ResetControlRule.requiresRestartCycleConfirmation(for: .complete))
    }
}
