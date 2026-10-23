import SwiftUI

struct ControlsBarView: View {
    let engine: TimerEngine

    @State private var isShowingRestartCycleConfirmation = false

    @Namespace private var glassNamespace

    @ScaledMetric(relativeTo: .body) private var primaryHorizontalPadding = 36.0
    @ScaledMetric(relativeTo: .body) private var primaryVerticalPadding = 14.0
    @ScaledMetric(relativeTo: .body) private var primaryFontSize = 17.0
    @ScaledMetric(relativeTo: .body) private var secondaryFontSize = 15.0

    private var accentDeep: Color { PassataPalette.accentDeep(for: engine.phase) }

    private var primaryLabel: String {
        ResetControlRule.primaryLabel(for: engine.status)
    }

    private var resetAction: ResetControlAction {
        ResetControlRule.action(for: engine.phase, sessionIndex: engine.sessionIndex, status: engine.status)
    }

    private var primaryIcon: String {
        engine.status == .running ? "pause.fill" : "play.fill"
    }

    var body: some View {
        VStack(spacing: 16) {
            Button(action: engine.togglePrimary) {
                Label(primaryLabel, systemImage: primaryIcon)
                    .font(.system(size: primaryFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, primaryVerticalPadding)
                    .padding(.horizontal, primaryHorizontalPadding)
            }
                    .disabled(engine.status == .complete)
                    .opacity(engine.status == .complete ? 0.35 : 1)
            .buttonStyle(.plain)
            .passataMacHoverFeedback()
            .glassEffect(.regular.tint(accentDeep), in: .capsule)

            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    Button(action: performReset) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(minHeight: 46)
                            .padding(.horizontal, 22)
                    }
                    .disabled(resetAction == .disabled)
                    .opacity(resetAction == .disabled ? 0.35 : 1)
                    .accessibilityLabel("Reset")
                    .accessibilityHint(ResetControlRule.accessibilityHint(for: resetAction))
                    .accessibilityAction(named: Text("Restart Cycle"), requestRestartCycle)
                    .contextMenu {
                        Button("Restart Cycle", systemImage: "arrow.counterclockwise", action: requestRestartCycle)
                    }
                    .passataMacHoverFeedback()
                    .glassEffect(.regular, in: .capsule)
                    .glassEffectUnion(id: "resetSkipGroup", namespace: glassNamespace)

                    Divider()
                        .padding(.vertical, 11)
                        .frame(height: 24)

                    Button(action: engine.onSkip) {
                        Label("Skip", systemImage: "forward.fill")
                            .frame(minHeight: 46)
                            .padding(.horizontal, 22)
                    }
                    .disabled(engine.status == .complete)
                    .opacity(engine.status == .complete ? 0.35 : 1)
                    .passataMacHoverFeedback()
                    .glassEffect(.regular, in: .capsule)
                    .glassEffectUnion(id: "resetSkipGroup", namespace: glassNamespace)
                }
                .font(.system(size: secondaryFontSize, weight: .medium))
                .foregroundStyle(Color("PassataInk2"))
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 30)
        .alert("Restart cycle?", isPresented: $isShowingRestartCycleConfirmation) {
            Button("Restart Cycle", role: .destructive) { engine.restartCycle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress in this cycle will be lost.")
        }
    }

    private func performReset() {
        resetAction.perform(on: engine)
    }

    private func requestRestartCycle() {
        if ResetControlRule.requiresRestartCycleConfirmation(for: engine.status) {
            isShowingRestartCycleConfirmation = true
        } else {
            engine.restartCycle()
        }
    }
}
