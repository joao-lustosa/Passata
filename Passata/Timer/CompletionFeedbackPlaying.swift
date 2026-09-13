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
        #endif
    }
}
