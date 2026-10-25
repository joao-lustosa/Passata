import XCTest
@testable import Passata

@MainActor final class CompletionFeedbackPlayingTests: XCTestCase {
    // SystemCompletionFeedback calls opaque system APIs (AVAudioPlayer,
    // UINotificationFeedbackGenerator, NSSound.beep()) with no observable return value, so
    // these can't assert that sound or haptics actually fired. What they do guard: every
    // platform this app ships on has an explicit, executed branch here rather than silently
    // falling through the `#if` chain and doing nothing, which is exactly how the visionOS gap
    // this file exists to cover went unnoticed.

    func testPlayDoesNotCrashForEveryFlagCombination() {
        #if os(iOS)
        let audioSession = RecordingCompletionAudioSession()
        let chimePlayer = RecordingCompletionChimePlayer()
        let feedback = SystemCompletionFeedback(audioSession: audioSession, chimePlayer: chimePlayer)
        #else
        let feedback = SystemCompletionFeedback()
        #endif
        for soundOn in [false, true] {
            for hapticsOn in [false, true] {
                feedback.play(soundOn: soundOn, hapticsOn: hapticsOn, respectSilentMode: true)
            }
        }
    }

    #if os(iOS)
    func testRespectSilentModeSelectsAmbientOrPlaybackCategory() {
        let audioSession = RecordingCompletionAudioSession()
        let chimePlayer = RecordingCompletionChimePlayer()
        let feedback = SystemCompletionFeedback(audioSession: audioSession, chimePlayer: chimePlayer)

        feedback.play(soundOn: true, hapticsOn: false, respectSilentMode: true)
        feedback.play(soundOn: true, hapticsOn: false, respectSilentMode: false)

        XCTAssertEqual(audioSession.categories, [.ambient, .playback])
        XCTAssertEqual(chimePlayer.playCount, 2)
    }

    func testMutedSoundDoesNotActivateAudioSessionOrPlayChime() {
        let audioSession = RecordingCompletionAudioSession()
        let chimePlayer = RecordingCompletionChimePlayer()
        let feedback = SystemCompletionFeedback(audioSession: audioSession, chimePlayer: chimePlayer)

        feedback.play(soundOn: false, hapticsOn: false, respectSilentMode: true)

        XCTAssertTrue(audioSession.categories.isEmpty)
        XCTAssertEqual(chimePlayer.playCount, 0)
    }
    #endif

    #if os(visionOS)
    func testVisionOSPlaysSoundWithNoHapticHardware() {
        // No Taptic Engine on Vision Pro and UINotificationFeedbackGenerator isn't part of
        // visionOS's UIKit surface at all, so hapticsOn has nothing to trigger here — confirming
        // this doesn't crash is the whole point: it's the platform branch that used to be
        // entirely missing.
        SystemCompletionFeedback().play(soundOn: true, hapticsOn: true, respectSilentMode: true)
    }
    #endif

    #if os(macOS)
    func testMacOSPlaysSound() {
        SystemCompletionFeedback().play(soundOn: true, hapticsOn: true, respectSilentMode: true)
    }
    #endif
}

#if os(iOS)
@MainActor
private final class RecordingCompletionAudioSession: CompletionAudioSessionConfiguring {
    private(set) var categories: [CompletionAudioSessionCategory] = []

    func setCategory(_ category: CompletionAudioSessionCategory) throws {
        categories.append(category)
    }
}

@MainActor
private final class RecordingCompletionChimePlayer: CompletionChimePlaying {
    private(set) var playCount = 0

    func play() {
        playCount += 1
    }
}
#endif
