import XCTest
@testable import Passata

@MainActor
final class ResetControlRuleTests: XCTestCase {
    func testResetIsDisabledOnlyAtTheStartOfFocusOne() {
        for phase in Phase.allCases {
            for sessionIndex in 1...TimerSettings.classicSessionsPerCycle {
                let action = ResetControlRule.action(for: phase, sessionIndex: sessionIndex, status: .idle)
                let shouldBeDisabled = phase == .focus && sessionIndex == 1
                XCTAssertEqual(action == .disabled, shouldBeDisabled, "\(phase), session \(sessionIndex)")
            }
        }
    }

    func testResetTapRestartsTheCycleOnlyWhenAnIdlePhaseIsAlreadyAtItsStart() {
        for phase in Phase.allCases {
            for sessionIndex in 1...TimerSettings.classicSessionsPerCycle {
                guard phase != .focus || sessionIndex != 1 else { continue }
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
                for sessionIndex in 1...TimerSettings.classicSessionsPerCycle {
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
