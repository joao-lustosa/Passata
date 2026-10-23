import SwiftUI

struct SettingsSheetView: View {
    let store: TimerSettingsStore
    let onClose: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.passataDebugReduceTransparency) private var debugReduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @ScaledMetric(relativeTo: .title) private var titleFontSize = 20.0
    @ScaledMetric(relativeTo: .caption) private var groupHeaderFontSize = 12.5
    @ScaledMetric(relativeTo: .caption) private var footerFontSize = 12.5

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.system(size: titleFontSize, weight: .bold))
                        .foregroundStyle(Color("PassataInk"))

                    Spacer()

                    Button(action: closeSettings) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("PassataInk2"))
                            .frame(width: 44, height: 44)
                            .background {
                                Circle()
                                    .fill(Color("PassataTrack"))
                                    .padding(7)
                            }
                    }
                    .buttonStyle(.plain)
                    .passataMacHoverFeedback()
                    .accessibilityLabel("Close settings")
                }
                .padding(.bottom, 6)

                sectionHeader("Timer")
                groupContainer {
                    DurationStepperRowView(
                        label: "Focus",
                        valueLabel: store.settings.durations.focusSeconds.asDurationSettingLabel,
                        entryValue: store.settings.durations.focusSeconds.asDurationInputString,
                        entryPrompt: "Enter minutes or m:ss, from 0:30 to 180:00.",
                        canDecrease: store.settings.durations.focusSeconds > DurationBounds.focus.lowerBound,
                        canIncrease: store.settings.durations.focusSeconds < DurationBounds.focus.upperBound,
                        onMinus: { store.adjustDuration(\.focusSeconds, delta: -DurationBounds.stepSeconds, in: DurationBounds.focus, affecting: .focus) },
                        onPlus: { store.adjustDuration(\.focusSeconds, delta: DurationBounds.stepSeconds, in: DurationBounds.focus, affecting: .focus) },
                        onValueSubmit: { store.typeDuration($0, affecting: .focus) }
                    )
                    rowDivider
                    DurationStepperRowView(
                        label: "Short Break",
                        valueLabel: store.settings.durations.shortBreakSeconds.asDurationSettingLabel,
                        entryValue: store.settings.durations.shortBreakSeconds.asDurationInputString,
                        entryPrompt: "Enter minutes or m:ss, from 0:30 to 60:00.",
                        canDecrease: store.settings.durations.shortBreakSeconds > DurationBounds.shortBreak.lowerBound,
                        canIncrease: store.settings.durations.shortBreakSeconds < DurationBounds.shortBreak.upperBound,
                        onMinus: { store.adjustDuration(\.shortBreakSeconds, delta: -DurationBounds.stepSeconds, in: DurationBounds.shortBreak, affecting: .shortBreak) },
                        onPlus: { store.adjustDuration(\.shortBreakSeconds, delta: DurationBounds.stepSeconds, in: DurationBounds.shortBreak, affecting: .shortBreak) },
                        onValueSubmit: { store.typeDuration($0, affecting: .shortBreak) }
                    )
                    rowDivider
                    DurationStepperRowView(
                        label: "Long Break",
                        valueLabel: store.settings.durations.longBreakSeconds.asDurationSettingLabel,
                        entryValue: store.settings.durations.longBreakSeconds.asDurationInputString,
                        entryPrompt: "Enter minutes or m:ss, from 0:30 to 60:00.",
                        canDecrease: store.settings.durations.longBreakSeconds > DurationBounds.longBreak.lowerBound,
                        canIncrease: store.settings.durations.longBreakSeconds < DurationBounds.longBreak.upperBound,
                        onMinus: { store.adjustDuration(\.longBreakSeconds, delta: -DurationBounds.stepSeconds, in: DurationBounds.longBreak, affecting: .longBreak) },
                        onPlus: { store.adjustDuration(\.longBreakSeconds, delta: DurationBounds.stepSeconds, in: DurationBounds.longBreak, affecting: .longBreak) },
                        onValueSubmit: { store.typeDuration($0, affecting: .longBreak) }
                    )
                    rowDivider
                    DurationStepperRowView(
                        label: "Sessions per cycle",
                        valueLabel: String(store.sessionsPerCycle),
                        entryValue: String(store.sessionsPerCycle),
                        entryPrompt: "Enter a whole number from 1 to 12.",
                        canDecrease: store.sessionsPerCycle > DurationBounds.sessionsPerCycle.lowerBound,
                        canIncrease: store.sessionsPerCycle < DurationBounds.sessionsPerCycle.upperBound,
                        onMinus: { store.adjustSessionsPerCycle(by: -1) },
                        onPlus: { store.adjustSessionsPerCycle(by: 1) },
                        onValueSubmit: { store.typeSessionsPerCycle($0) }
                    )
                    rowDivider
                    Button("Reset to Defaults", action: store.resetToDefaults)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("PassataInk"))
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                sectionHeader("Notifications")
                groupContainer {
                    ToggleRowView(label: "Sound", isOn: soundBinding)
                    rowDivider
                    ToggleRowView(label: "Haptics", isOn: hapticsBinding)
                    rowDivider
                    ToggleRowView(label: "Auto-Start Next Phase", isOn: autoStartBinding)
                    #if os(iOS)
                    rowDivider
                    ToggleRowView(label: "Respect Silent Mode", isOn: respectSilentModeBinding)
                    #endif
                }
                #if os(iOS)
                Text("Notifications always follow your iPhone's silent setting")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color("PassataInk2"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 7)
                #endif

                VStack(spacing: 2) {
                    Text("Passata")
                    Text("Version 1.0")
                }
                .font(.system(size: footerFontSize))
                .foregroundStyle(Color("PassataInk2"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 24)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .confirmationDialog(
            "Duration change",
            isPresented: durationConfirmationBinding,
            presenting: store.pendingDurationChange
        ) { pending in
            Button("Restart Session") {
                store.resolvePendingDurationChange(restartCurrentPhase: true)
            }
            Button("Apply Next Session") {
                store.resolvePendingDurationChange(restartCurrentPhase: false)
            }
            Button("Cancel", role: .cancel) {
                store.cancelPendingDurationChange()
            }
        } message: { pending in
            if pending.isResetToDefaults {
                Text("Reset all durations and sessions per cycle? The current phase needs to restart or use its new duration next session.")
            } else {
                Text("Changing the current phase duration affects this session.")
            }
        }
        .onDisappear(perform: store.cancelPendingDurationChange)
    }

    private var durationConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.pendingDurationChange != nil },
            set: { isPresented in
                // The action buttons resolve or cancel the pending change. Do not clear it
                // from this dismissal setter before the selected action has run.
                if isPresented { return }
            }
        )
    }

    private func closeSettings() {
        store.cancelPendingDurationChange()
        onClose()
    }

    private var soundBinding: Binding<Bool> {
        Binding(get: { store.settings.soundOn }, set: { _ in store.toggleSound() })
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticsOn }, set: { _ in store.toggleHaptics() })
    }

    private var autoStartBinding: Binding<Bool> {
        Binding(get: { store.settings.autoStartNext }, set: { _ in store.toggleAutoStart() })
    }

    #if os(iOS)
    private var respectSilentModeBinding: Binding<Bool> {
        Binding(get: { store.settings.respectSilentMode }, set: { _ in store.toggleRespectSilentMode() })
    }
    #endif

    private var rowDivider: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.08))
            .frame(height: 0.5)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: groupHeaderFontSize, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Color("PassataInk2"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 22)
            .padding(.bottom, 7)
    }

    private func groupContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
            .background(groupBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                }
            }
    }

    private var groupBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(PassataPalette.settingsGroupBackground(
                colorScheme: colorScheme,
                reduceTransparency: reduceTransparency || debugReduceTransparency
            ))
    }
}

#Preview("Settings content") {
    SettingsSheetView(
        store: TimerSettingsStore(persister: PreviewSettingsPersister()),
        onClose: {}
    )
    .background(Color("PassataBackground"))
}

private final class PreviewSettingsPersister: SettingsPersisting {
    func load() -> TimerSettings? { nil }
    func save(_ settings: TimerSettings) {}
}
