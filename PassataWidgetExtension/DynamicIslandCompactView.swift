import SwiftUI

struct DynamicIslandCompactLeadingView: View {
    let state: PassataActivityAttributes.ContentState

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    var body: some View {
        progressView
            .frame(width: 19, height: 19)
            .padding(.leading, 12)
            .padding(.trailing, 6)
    }

    @ViewBuilder
    private var progressView: some View {
        switch state.render {
        case let .running(phaseStart, phaseEnd):
            ProgressView(timerInterval: phaseStart...phaseEnd, countsDown: false)
                .tint(accent)
                .progressViewStyle(.circular)
        default:
            ProgressView(value: state.render.staticProgress)
                .tint(accent)
                .progressViewStyle(.circular)
        }
    }
}

struct DynamicIslandCompactTrailingView: View {
    let state: PassataActivityAttributes.ContentState

    var body: some View {
        timeContent
            .font(.system(size: 15, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.leading, 6)
            .padding(.trailing, 13)
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

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
