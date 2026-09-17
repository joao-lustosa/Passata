import SwiftUI

struct ProgressRingView: View {
    let engine: TimerEngine
    let durationProvider: any DurationProviding

    @ScaledMetric(relativeTo: .largeTitle) private var ringDiameter = 250.0
    @ScaledMetric(relativeTo: .largeTitle) private var numeralFontSize = 76.0
    @ScaledMetric(relativeTo: .largeTitle) private var phaseFontSize = 13.0
    @ScaledMetric(relativeTo: .largeTitle) private var pausedTagFontSize = 13.0

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.passataDebugReduceTransparency) private var debugReduceTransparency

    private let strokeWidth = 16.0

    private var accent: Color { PassataPalette.accent(for: engine.phase) }

    private var progress: Double {
        let duration = durationProvider.duration(for: engine.phase)
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - Double(engine.remainingSeconds) / Double(duration)))
    }

    private var timeLabel: String {
        engine.remainingSeconds.asClockString
    }

    private var phaseLabel: String {
        engine.phase.displayName
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(ringDiameter, max(0, proxy.size.width - 48))
            ringContent(diameter: diameter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phaseLabel), \(timeLabel)\(engine.status == .paused ? ", paused" : "")")
    }

    private func boundedNumeralFontSize(for diameter: Double) -> Double {
        min(numeralFontSize, (diameter - strokeWidth * 2 - 30) / 2.3)
    }

    @ViewBuilder
    private func ringContent(diameter: Double) -> some View {
        ZStack {
            ringHalo(diameter: diameter)

            ZStack {
                Circle()
                    .stroke(Color("PassataTrack").opacity(reduceTransparency || debugReduceTransparency ? 1 : 0.55), lineWidth: strokeWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)

                VStack(spacing: 6) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                        Text(phaseLabel.uppercased())
                            .font(.system(size: phaseFontSize, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color("PassataInk2"))
                    }

                    Text(timeLabel)
                        .font(.system(size: boundedNumeralFontSize(for: diameter), weight: .thin))
                        .monospacedDigit()
                        .tracking(-1.5)
                        .foregroundStyle(Color("PassataInk"))
                        .lineLimit(1)

                    if engine.status == .paused {
                        Text("Paused")
                            .font(.system(size: pausedTagFontSize, weight: .medium))
                            .foregroundStyle(Color("PassataInk2"))
                            .padding(.top, 2)
                    }
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter + 21, height: diameter + 21)
    }

    // glassEffect fallback: on iOS 27, Liquid Glass's darkened edge plus brighter specular
    // highlights compress this 7pt annulus into a hard ring with a bright highlight band
    // rather than the mockup's soft, accent-tinted ambient glow (confirmed by screenshot
    // comparison, not assumed) — thinner than any other glass surface in this app was ever
    // going to survive that treatment. A blurred stroke reproduces the intended look directly
    // instead. Leaving glassEffect means its automatic Reduce Transparency degrade goes with
    // it, so that branch is written explicitly here.
    @ViewBuilder
    private func ringHalo(diameter: Double) -> some View {
        if reduceTransparency || debugReduceTransparency {
            Circle()
                .stroke(accent.opacity(0.10), lineWidth: 7)
                .frame(width: diameter + 21, height: diameter + 21)
        } else {
            Circle()
                .stroke(accent.opacity(0.12), lineWidth: 7)
                .frame(width: diameter + 21, height: diameter + 21)
                .blur(radius: 3)
        }
    }
}

#Preview("Paused focus ring") {
    let durationProvider = PreviewDurationProvider()
    let engine = TimerEngine(durationProvider: durationProvider, persister: NoOpTimerStateStore())
    engine.start()
    engine.pause()

    return ProgressRingView(engine: engine, durationProvider: durationProvider)
        .padding(28)
        .background(Color("PassataBackground"))
}

private struct PreviewDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int {
        PhaseDurations.classic.seconds(for: phase)
    }
}
