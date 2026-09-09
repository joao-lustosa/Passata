import AudioToolbox
import UIKit

protocol CompletionFeedbackPlaying {
    func play(soundOn: Bool, hapticsOn: Bool)
}

struct SystemCompletionFeedback: CompletionFeedbackPlaying {
    func play(soundOn: Bool, hapticsOn: Bool) {
        if soundOn { AudioServicesPlaySystemSound(1005) }
        if hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}
