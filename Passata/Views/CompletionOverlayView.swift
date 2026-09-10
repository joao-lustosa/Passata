import SwiftUI

/// Present this from a parent when `engine.status == .complete`, with the parent's transition.
/// The CTA is intentionally the only dismissal path for this completion gate.
struct CompletionOverlayView: View {
    let engine: TimerEngine

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @ScaledMetric(relativeTo: .title) private var titleFontSize = 20.0
    @ScaledMetric(relativeTo: .body) private var subtitleFontSize = 14.0
    @ScaledMetric(relativeTo: .body) private var ctaFontSize = 16.0

    private var next: (phase: Phase, sessionIndex: Int) {
        engine.phase.next(sessionIndex: engine.sessionIndex, sessionsPerCycle: engine.sessionsPerCycle)
    }

    private var accentDeep: Color { PassataPalette.accentDeep(for: engine.phase) }
    private var nextAccentDeep: Color { PassataPalette.accentDeep(for: next.phase) }

    private var title: String {
        switch engine.phase {
        case .focus: "Focus Complete"
        case .shortBreak: "Short Break Complete"
        case .longBreak: "Long Break Complete"
        }
    }

    private var subtitle: String {
        if engine.phase == .longBreak {
            return "Cycle complete. Start when you're ready."
        }

        if engine.autoStartNext {
            switch next.phase {
            case .focus: return "Starting the next session…"
            case .shortBreak: return "Starting your short break…"
            case .longBreak: return "Starting your long break…"
            }
        }

        switch next.phase {
        case .focus: return "Ready for the next focus session."
        case .shortBreak: return "Time for a short break."
        case .longBreak: return "Time for a long break."
        }
    }

    private var ctaLabel: String {
        switch next.phase {
        case .focus: "Start Focus"
        case .shortBreak: "Start Short Break"
        case .longBreak: "Start Long Break"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backdrop

                VStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(accentDeep, in: Circle())

                    Text(title)
                        .font(.system(size: titleFontSize, weight: .bold))
                        .foregroundStyle(Color("PassataInk"))

                    Text(subtitle)
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(Color("PassataInk2"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)

                    Button(action: engine.onStartNext) {
                        Text(ctaLabel)
                            .font(.system(size: ctaFontSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 13)
                            .padding(.horizontal, 30)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .glassEffect(.regular.tint(nextAccentDeep), in: .capsule)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 26)
                .frame(width: min(proxy.size.width * 0.82, 300))
                .background { cardBackground }
                .shadow(color: .black.opacity(0.25), radius: 25, y: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backdrop: some View {
        Group {
            if colorScheme == .dark {
                Color.black.opacity(0.55)
            } else {
                Color(red: 30 / 255, green: 20 / 255, blue: 14 / 255).opacity(0.50)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PassataPalette.overlayCardRTBackground())
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06),
                            lineWidth: 0.5
                        )
                }
        } else if colorScheme == .light {
            // Workaround for a Liquid Glass compositing anomaly in this inline ZStack context.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PassataPalette.overlayCardRTBackground())
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                }
        } else {
            let overlayCardGlassTint = Color(red: 40 / 255, green: 40 / 255, blue: 46 / 255).opacity(0.78)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(overlayCardGlassTint), in: .rect(cornerRadius: 28))
        }
    }
}

#Preview("Focus complete") {
    let durationProvider = CompletionOverlayPreviewDurationProvider()
    let engine = TimerEngine(durationProvider: durationProvider, persister: NoOpTimerStateStore())

    return CompletionOverlayView(engine: engine)
        .frame(width: 390, height: 844)
}

private struct CompletionOverlayPreviewDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int {
        switch phase {
        case .focus: 25 * 60
        case .shortBreak: 5 * 60
        case .longBreak: 15 * 60
        }
    }
}
