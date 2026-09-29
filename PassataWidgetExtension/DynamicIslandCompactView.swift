import SwiftUI

struct DynamicIslandCompactLeadingView: View {
    let state: PassataActivityAttributes.ContentState

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    var body: some View {
        ActivityProgressView(render: state.render, accent: accent)
            .frame(width: 19, height: 19)
            .padding(.leading, 12)
            .padding(.trailing, 6)
    }
}

struct ActivityProgressView: View {
    let render: RenderState
    let accent: Color

    @ViewBuilder
    var body: some View {
        switch render {
        case let .running(phaseStart, phaseEnd):
            ProgressView(timerInterval: phaseStart...phaseEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
                .tint(accent)
                .progressViewStyle(.circular)
        default:
            DeterminateCircularProgressView(progress: render.staticProgress, accent: accent)
        }
    }
}

struct DeterminateCircularProgressView: View {
    let progress: Double
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.3), lineWidth: 3.6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview("Compact progress states") {
    let now = Date()
    let states = [
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .idle(phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .running(phaseStart: now.addingTimeInterval(-300), phaseEnd: now.addingTimeInterval(1200))),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .paused(remainingSeconds: 600, phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .complete)
    ]

    return VStack(spacing: 12) {
        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
            DynamicIslandCompactLeadingView(state: state)
                .background(.black)
        }
    }
}

struct DynamicIslandCompactTrailingView: View {
    let state: PassataActivityAttributes.ContentState

    var body: some View {
        LiveActivityTimeText(render: state.render)
            .font(.system(size: 15, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.leading, 6)
            .padding(.trailing, 13)
    }
}
