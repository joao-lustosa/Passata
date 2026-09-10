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

                    Button(action: onClose) {
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
                    .accessibilityLabel("Close settings")
                }
                .padding(.bottom, 6)

                sectionHeader("Timer")
                groupContainer {
                    PresetRowView(label: "Preset", valueLabel: presetLabel, onTap: store.cyclePreset)
                    rowDivider
                    DurationStepperRowView(
                        label: "Focus",
                        valueLabel: "\(store.settings.durations.focusMinutes) min",
                        onMinus: { store.adjustDuration(\.focusMinutes, delta: -5, in: 5...90, affecting: .focus) },
                        onPlus: { store.adjustDuration(\.focusMinutes, delta: 5, in: 5...90, affecting: .focus) }
                    )
                    rowDivider
                    DurationStepperRowView(
                        label: "Short Break",
                        valueLabel: "\(store.settings.durations.shortBreakMinutes) min",
                        onMinus: { store.adjustDuration(\.shortBreakMinutes, delta: -1, in: 1...30, affecting: .shortBreak) },
                        onPlus: { store.adjustDuration(\.shortBreakMinutes, delta: 1, in: 1...30, affecting: .shortBreak) }
                    )
                    rowDivider
                    DurationStepperRowView(
                        label: "Long Break",
                        valueLabel: "\(store.settings.durations.longBreakMinutes) min",
                        onMinus: { store.adjustDuration(\.longBreakMinutes, delta: -5, in: 5...60, affecting: .longBreak) },
                        onPlus: { store.adjustDuration(\.longBreakMinutes, delta: 5, in: 5...60, affecting: .longBreak) }
                    )
                }

                sectionHeader("Notifications")
                groupContainer {
                    ToggleRowView(label: "Sound", isOn: soundBinding)
                    rowDivider
                    ToggleRowView(label: "Haptics", isOn: hapticsBinding)
                    rowDivider
                    ToggleRowView(label: "Auto-Start Next Phase", isOn: autoStartBinding)
                }

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
    }

    private var presetLabel: String {
        switch store.settings.preset {
        case .classic: "Classic"
        case .deep: "Deep Work"
        case .short: "Short Bursts"
        case .custom: "Custom"
        }
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
