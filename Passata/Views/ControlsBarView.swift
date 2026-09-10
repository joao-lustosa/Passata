import SwiftUI

struct ControlsBarView: View {
    let engine: TimerEngine

    @ScaledMetric(relativeTo: .body) private var primaryHorizontalPadding = 36.0
    @ScaledMetric(relativeTo: .body) private var primaryVerticalPadding = 14.0
    @ScaledMetric(relativeTo: .body) private var primaryFontSize = 17.0
    @ScaledMetric(relativeTo: .body) private var secondaryFontSize = 15.0

    private var accentDeep: Color { PassataPalette.accentDeep(for: engine.phase) }

    private var primaryLabel: String {
        switch engine.status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .complete: ""
        }
    }

    private var primaryIcon: String {
        engine.status == .running ? "pause.fill" : "play.fill"
    }

    var body: some View {
        VStack(spacing: 16) {
            if engine.status != .complete {
                Button(action: engine.togglePrimary) {
                    Label(primaryLabel, systemImage: primaryIcon)
                        .font(.system(size: primaryFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, primaryVerticalPadding)
                        .padding(.horizontal, primaryHorizontalPadding)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(accentDeep), in: .capsule)
            }

            HStack(spacing: 0) {
                Button(action: engine.onReset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(minHeight: 46)
                        .padding(.horizontal, 22)
                }
                .disabled(engine.status == .idle)
                .opacity(engine.status == .idle ? 0.35 : 1)

                Divider()
                    .padding(.vertical, 11)
                    .frame(height: 24)

                Button(action: engine.onSkip) {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(minHeight: 46)
                        .padding(.horizontal, 22)
                }
            }
            .font(.system(size: secondaryFontSize, weight: .medium))
            .foregroundStyle(Color("PassataInk2"))
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .capsule)
        }
        .disabled(engine.status == .complete)
        .opacity(engine.status == .complete ? 0.25 : 1)
        .padding(.top, 4)
        .padding(.bottom, 30)
    }
}
