import SwiftUI

struct DynamicIslandExpandedView: View {
    let state: PassataActivityAttributes.ContentState

    private let track = Color.white.opacity(0.22)

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                pauseControl
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(state.phase.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    LiveActivitySessionDotsView(
                        phase: state.phase,
                        sessionIndex: state.sessionIndex,
                        sessionsPerCycle: state.sessionsPerCycle,
                        accent: accent
                    )
                }
                LiveActivityTimeText(render: state.render)
                    .font(.system(size: 40, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 132, alignment: .trailing)
            }
            .frame(height: 48)

            LiveActivityLinearProgressBar(render: state.render, accent: accent, track: track)
                .frame(height: 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // Non-interactive placeholder -- AppIntent-driven pause/resume remains deferred.
    private var pauseControl: some View {
        let isRunning: Bool
        let label: String
        switch state.render {
        case .running:
            isRunning = true
            label = "Pause"
        case .paused:
            isRunning = false
            label = "Resume"
        case .idle, .complete:
            isRunning = false
            label = "Start"
        }

        return Image(systemName: isRunning ? "pause.fill" : "play.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: 44, height: 44)
            .background(accent.opacity(0.22), in: Circle())
            .accessibilityLabel(label)
    }
}

#Preview("Dynamic Island expanded progress states") {
    let now = Date()
    let states = [
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .idle(phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .running(phaseStart: now.addingTimeInterval(-300), phaseEnd: now.addingTimeInterval(1200))),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .paused(remainingSeconds: 600, phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .complete)
    ]

    return VStack(spacing: 12) {
        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
            DynamicIslandExpandedView(state: state)
                .background(.black)
        }
    }
}
