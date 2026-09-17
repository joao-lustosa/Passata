import Foundation
import XCTest
@testable import Passata

@MainActor
final class RenderStateTests: XCTestCase {
    func testStaticProgressForEveryStateAndPausedBoundary() {
        let cases: [(RenderState, Double)] = [
            (.idle(phaseDurationSeconds: 120), 0),
            (.complete, 1),
            (.running(phaseStart: Date(timeIntervalSinceReferenceDate: 100),
                      phaseEnd: Date(timeIntervalSinceReferenceDate: 220)), 0),
            (.paused(remainingSeconds: 120, phaseDurationSeconds: 120), 0),
            (.paused(remainingSeconds: 90, phaseDurationSeconds: 120), 0.25),
            (.paused(remainingSeconds: 30, phaseDurationSeconds: 120), 0.75),
            (.paused(remainingSeconds: 0, phaseDurationSeconds: 120), 1),
            (.paused(remainingSeconds: 30, phaseDurationSeconds: 0), 0),
            (.paused(remainingSeconds: 30, phaseDurationSeconds: -1), 0)
        ]
        for (state, expected) in cases {
            XCTAssertEqual(state.staticProgress, expected, accuracy: 0.000001)
        }
    }

    func testCodableRoundTripPreservesAllCasesAndFractionalDates() throws {
        let states: [RenderState] = [
            .idle(phaseDurationSeconds: 1500),
            .running(phaseStart: Date(timeIntervalSinceReferenceDate: 1_000.25),
                     phaseEnd: Date(timeIntervalSinceReferenceDate: 2_500.75)),
            .paused(remainingSeconds: 89, phaseDurationSeconds: 120),
            .complete
        ]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RenderState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }
}
