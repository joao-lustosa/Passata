import XCTest
@testable import Passata

final class CompletionFeedbackPlayingTests: XCTestCase {
    // SystemCompletionFeedback calls opaque system APIs (AudioServicesPlaySystemSound,
    // UINotificationFeedbackGenerator, NSSound.beep()) with no observable return value, so
    // these can't assert that sound or haptics actually fired. What they do guard: every
    // platform this app ships on has an explicit, executed branch here rather than silently
    // falling through the `#if` chain and doing nothing, which is exactly how the visionOS gap
    // this file exists to cover went unnoticed.

    func testPlayDoesNotCrashForEveryFlagCombination() {
        let feedback = SystemCompletionFeedback()
        for soundOn in [false, true] {
            for hapticsOn in [false, true] {
                feedback.play(soundOn: soundOn, hapticsOn: hapticsOn)
            }
        }
    }

    #if os(visionOS)
    func testVisionOSPlaysSoundWithNoHapticHardware() {
        // No Taptic Engine on Vision Pro and UINotificationFeedbackGenerator isn't part of
        // visionOS's UIKit surface at all, so hapticsOn has nothing to trigger here — confirming
        // this doesn't crash is the whole point: it's the platform branch that used to be
        // entirely missing.
        SystemCompletionFeedback().play(soundOn: true, hapticsOn: true)
    }
    #endif

    #if os(iOS)
    func testIOSPlaysSoundAndHaptics() {
        SystemCompletionFeedback().play(soundOn: true, hapticsOn: true)
    }
    #endif

    #if os(macOS)
    func testMacOSPlaysSound() {
        SystemCompletionFeedback().play(soundOn: true, hapticsOn: true)
    }
    #endif
}
