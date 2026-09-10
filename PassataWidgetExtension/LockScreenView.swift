import SwiftUI

struct LockScreenView: View {
    let state: PassataActivityAttributes.ContentState

    private let ink = Color.white
    private let ink2 = Color.white.opacity(0.62)
    private let track = Color.white.opacity(0.22)
    private let material = Color.white.opacity(0.16)

    private var phaseLabel: String {
        switch state.phase {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
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
                        .foregroundStyle(ink2)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(material, in: Capsule())
                }
            }
            progressView
            sessionDots
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
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

    private var timeView: some View {
        timeContent
            .font(.system(size: 46, weight: .light))
            .monospacedDigit()
            .tracking(-1.5)
            .foregroundStyle(ink)
    }

    @ViewBuilder
    private var progressView: some View {
        switch state.render {
        case let .running(phaseStart, phaseEnd):
            ProgressView(timerInterval: phaseStart...phaseEnd, countsDown: false)
                .tint(accent)
                .progressViewStyle(.linear)
        default:
            GeometryReader { proxy in
                Capsule()
                    .fill(track)
                    .overlay(alignment: .leading) {
                        Capsule().fill(accent).frame(width: proxy.size.width * CGFloat(state.render.staticProgress))
                    }
            }
            .frame(height: 6)
        }
    }

    private var sessionDots: some View {
        let filledCount = state.phase == .focus ? state.sessionIndex - 1 : state.sessionIndex
        return HStack(spacing: 5) {
            ForEach(1...4, id: \.self) { dotNumber in
                let filled = dotNumber <= filledCount
                let current = state.phase == .focus && dotNumber == state.sessionIndex && !filled
                Circle()
                    .fill(filled ? accent : Color.clear)
                    .overlay {
                        if current {
                            Circle().stroke(accent, lineWidth: 1.5)
                        } else if !filled {
                            Circle().stroke(Color.white.opacity(0.42), lineWidth: 1.5)
                        }
                    }
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
