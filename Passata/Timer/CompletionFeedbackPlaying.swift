#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

protocol CompletionFeedbackPlaying {
    func play(soundOn: Bool, hapticsOn: Bool)
}

struct SystemCompletionFeedback: CompletionFeedbackPlaying {
    func play(soundOn: Bool, hapticsOn: Bool) {
        #if os(iOS)
        if soundOn { AudioServicesPlaySystemSound(1005) }
        if hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        #elseif os(macOS)
        if soundOn { NSSound.beep() }
        #elseif os(visionOS)
        // Vision Pro has no Taptic Engine, and UINotificationFeedbackGenerator isn't part of
        // visionOS's UIKit surface at all (not a case of it silently doing nothing) — sound is
        // the only feedback channel available here.
        if soundOn { AudioServicesPlaySystemSound(1005) }
        #endif
    }
}
