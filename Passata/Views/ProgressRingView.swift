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
        String(format: "%02d:%02d", engine.remainingSeconds / 60, engine.remainingSeconds % 60)
    }

    private var phaseLabel: String {
        switch engine.phase {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    private var boundedNumeralFontSize: Double {
        min(numeralFontSize, (ringDiameter - strokeWidth * 2 - 30) / 2.3)
    }

    var body: some View {
        ZStack {
            GlassHaloShape(lineWidth: 24)
                .fill(.clear)
                .frame(width: ringDiameter + 28, height: ringDiameter + 28)
                .glassEffect(.regular.tint(accent), in: GlassHaloShape(lineWidth: 24))

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
                    .font(.system(size: boundedNumeralFontSize, weight: .ultraLight))
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
        .frame(width: ringDiameter, height: ringDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phaseLabel), \(timeLabel)\(engine.status == .paused ? ", paused" : "")")
    }
}

private struct GlassHaloShape: Shape {
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = max(0, outerRadius - lineWidth)
        var path = Path()

        path.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        path.closeSubpath()
        path.addArc(center: center, radius: innerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: true)
        path.closeSubpath()
        return path
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
        switch phase {
        case .focus: 25 * 60
        case .shortBreak: 5 * 60
        case .longBreak: 15 * 60
        }
    }
}
