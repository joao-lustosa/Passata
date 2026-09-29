import Foundation
import Testing
@testable import Passata

@Test(arguments: [
    (RenderState.idle(phaseDurationSeconds: 120), 0.0),
    (.complete, 1.0),
    (.running(phaseStart: Date(timeIntervalSinceReferenceDate: 100),
              phaseEnd: Date(timeIntervalSinceReferenceDate: 220)), 0.0),
    (.paused(remainingSeconds: 120, phaseDurationSeconds: 120), 0.0),
    (.paused(remainingSeconds: 90, phaseDurationSeconds: 120), 0.25),
    (.paused(remainingSeconds: 30, phaseDurationSeconds: 120), 0.75),
    (.paused(remainingSeconds: 0, phaseDurationSeconds: 120), 1.0),
    (.paused(remainingSeconds: 30, phaseDurationSeconds: 0), 0.0),
    (.paused(remainingSeconds: 30, phaseDurationSeconds: -1), 0.0)
])
func staticProgress(state: RenderState, expected: Double) {
    #expect(abs(state.staticProgress - expected) < 0.000001)
}

@Test(arguments: [
    RenderState.idle(phaseDurationSeconds: 1500),
    .running(phaseStart: Date(timeIntervalSinceReferenceDate: 1_000.25),
             phaseEnd: Date(timeIntervalSinceReferenceDate: 2_500.75)),
    .paused(remainingSeconds: 89, phaseDurationSeconds: 120),
    .complete
])
func codableRoundTrip(state: RenderState) throws {
    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(RenderState.self, from: data)
    #expect(decoded == state)
}
