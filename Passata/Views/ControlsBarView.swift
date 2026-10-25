import SwiftUI

struct ControlsBarView: View {
    let engine: TimerEngine

    @State private var isShowingRestartCycleConfirmation = false

    @Namespace private var glassNamespace

    @ScaledMetric(relativeTo: .body) private var primaryHorizontalPadding = 36.0
    @ScaledMetric(relativeTo: .body) private var primaryVerticalPadding = 14.0
    @ScaledMetric(relativeTo: .body) private var primaryFontSize = 17.0
    @ScaledMetric(relativeTo: .body) private var secondaryFontSize = 15.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

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
                    .padding(.horizontal, usesAccessibilityLayout ? 12 : primaryHorizontalPadding)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: usesAccessibilityLayout ? .infinity : nil)
            .disabled(engine.status == .complete)
            .opacity(engine.status == .complete ? 0.35 : 1)
            .buttonStyle(.plain)
            .passataMacHoverFeedback()
            .glassEffect(.regular.tint(accentDeep), in: .capsule)

            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    Button(action: performReset) {
                        resetButtonLabel
                            .frame(minHeight: 46)
                            .padding(.horizontal, usesAccessibilityLayout ? 6 : 22)
                    }
                    .frame(maxWidth: usesAccessibilityLayout ? .infinity : nil)
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
                        skipButtonLabel
                            .frame(minHeight: 46)
                            .padding(.horizontal, usesAccessibilityLayout ? 6 : 22)
                    }
                    .frame(maxWidth: usesAccessibilityLayout ? .infinity : nil)
                    .disabled(engine.status == .complete)
                    .opacity(engine.status == .complete ? 0.35 : 1)
                    .passataMacHoverFeedback()
                    .glassEffect(.regular, in: .capsule)
                    .glassEffectUnion(id: "resetSkipGroup", namespace: glassNamespace)
                }
                .font(.system(size: secondaryFontSize, weight: .medium))
                .foregroundStyle(Color("PassataInk2"))
                .buttonStyle(.plain)
                .frame(maxWidth: usesAccessibilityLayout ? .infinity : nil)
            }
        }
        .padding(.horizontal, usesAccessibilityLayout ? 20 : 0)
        .padding(.top, 4)
        .padding(.bottom, usesAccessibilityLayout ? 16 : 30)
        .frame(maxWidth: .infinity)
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

    @ViewBuilder
    private var resetButtonLabel: some View {
        if usesAccessibilityLayout {
            Text("Reset")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            Label("Reset", systemImage: "arrow.counterclockwise")
        }
    }

    @ViewBuilder
    private var skipButtonLabel: some View {
        if usesAccessibilityLayout {
            Text("Skip")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            Label("Skip", systemImage: "forward.fill")
        }
    }

    private func requestRestartCycle() {
        if ResetControlRule.requiresRestartCycleConfirmation(for: engine.status) {
            isShowingRestartCycleConfirmation = true
        } else {
            engine.restartCycle()
        }
    }
}
