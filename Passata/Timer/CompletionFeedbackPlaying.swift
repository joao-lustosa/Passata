#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import AVFoundation
#endif
#if os(macOS)
import AppKit
#endif

protocol CompletionFeedbackPlaying {
    func play(soundOn: Bool, hapticsOn: Bool, respectSilentMode: Bool)
}

enum CompletionAudioSessionCategory: Equatable {
    case ambient
    case playback
}

#if os(iOS)
protocol CompletionAudioSessionConfiguring {
    func setCategory(_ category: CompletionAudioSessionCategory) throws
}

protocol CompletionChimePlaying {
    func play()
}

struct SystemCompletionAudioSession: CompletionAudioSessionConfiguring {
    func setCategory(_ category: CompletionAudioSessionCategory) throws {
        let session = AVAudioSession.sharedInstance()
        switch category {
        case .ambient:
            try session.setCategory(.ambient)
        case .playback:
            try session.setCategory(.playback)
        }
    }
}

final class SystemCompletionChimePlayer: CompletionChimePlaying {
    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(forResource: "CompletionChime", withExtension: "caf") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            player.prepareToPlay()
            player.play()
        } catch {
            // Feedback is best-effort and must never interrupt timer completion.
        }
    }
}
#endif

struct SystemCompletionFeedback: CompletionFeedbackPlaying {
    #if os(iOS)
    private let audioSession: any CompletionAudioSessionConfiguring
    private let chimePlayer: any CompletionChimePlaying

    init(
        audioSession: any CompletionAudioSessionConfiguring = SystemCompletionAudioSession(),
        chimePlayer: any CompletionChimePlaying = SystemCompletionChimePlayer()
    ) {
        self.audioSession = audioSession
        self.chimePlayer = chimePlayer
    }
    #endif

    func play(soundOn: Bool, hapticsOn: Bool, respectSilentMode: Bool) {
        #if os(iOS)
        if soundOn {
            let category: CompletionAudioSessionCategory = respectSilentMode ? .ambient : .playback
            do {
                try audioSession.setCategory(category)
                chimePlayer.play()
            } catch {
                // Audio-session failures must not prevent completion haptics or timer progress.
            }
        }
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
