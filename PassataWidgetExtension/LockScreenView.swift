import SwiftUI

struct LockScreenView: View {
    let state: PassataActivityAttributes.ContentState

    private let ink = Color.white
    private let ink2 = Color.white.opacity(0.62)
    private let track = Color.white.opacity(0.22)
    private let material = Color.white.opacity(0.16)

    private var phaseLabel: String {
        state.phase.displayName
    }

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                // TODO: replace the timer glyph with the final app icon artwork.
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 7.5))
                Text("Passata")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text(phaseLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ink)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                timeView
                if case .paused = state.render {
                    Text("Paused")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(material, in: Capsule())
                }
            }
            LiveActivityLinearProgressBar(render: state.render, accent: accent, track: track)
            LiveActivitySessionDotsView(
                phase: state.phase,
                sessionIndex: state.sessionIndex,
                sessionsPerCycle: state.sessionsPerCycle,
                accent: accent
            )
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
    }

    private var timeView: some View {
        LiveActivityTimeText(render: state.render)
            .font(.system(size: 46, weight: .light))
            .monospacedDigit()
            .tracking(-1.5)
            .foregroundStyle(ink)
    }


}

#Preview("Lock Screen progress states") {
    let now = Date()
    let states = [
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .idle(phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .running(phaseStart: now.addingTimeInterval(-300), phaseEnd: now.addingTimeInterval(1200))),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .paused(remainingSeconds: 600, phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .complete)
    ]

    return VStack(spacing: 12) {
        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
            LockScreenView(state: state)
                .background(.black)
        }
    }
}
