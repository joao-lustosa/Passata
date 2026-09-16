import SwiftUI

struct DynamicIslandExpandedView: View {
    let state: PassataActivityAttributes.ContentState

    private let track = Color.white.opacity(0.22)
    private let material = Color.white.opacity(0.16)

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    private var phaseLabel: String {
        switch state.phase {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // TODO: replace the timer glyph with the final app icon artwork.
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 7.5))
                Text(phaseLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                timeContent
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            progressView

            HStack(alignment: .center, spacing: 12) {
                LiveActivitySessionDotsView(
                    phase: state.phase,
                    sessionIndex: state.sessionIndex,
                    sessionsPerCycle: state.sessionsPerCycle,
                    accent: accent
                )
                Spacer(minLength: 0)
                pauseControl
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var timeContent: some View {
        switch state.render {
        case let .running(phaseStart, phaseEnd):
            Text(timerInterval: phaseStart...phaseEnd, countsDown: true)
        case let .idle(seconds), let .paused(seconds, _):
            Text(formatted(seconds: seconds))
        case .complete:
            Text("00:00")
        }
    }

    @ViewBuilder
    private var progressView: some View {
        switch state.render {
        case let .running(phaseStart, phaseEnd):
            ProgressView(timerInterval: phaseStart...phaseEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
                .tint(accent)
                .progressViewStyle(.linear)
        default:
            GeometryReader { proxy in
                Capsule()
                    .fill(track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * CGFloat(state.render.staticProgress))
                    }
            }
            .frame(height: 6)
        }
    }

    // Non-interactive placeholder -- AppIntent-driven pause/resume deferred, see architect-spec.md section 14.6.
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

        return HStack(spacing: 6) {
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(minHeight: 44)
        .padding(.horizontal, 18)
        .background(material, in: Capsule())
    }

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
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
