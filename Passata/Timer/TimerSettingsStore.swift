import Observation

@Observable final class TimerSettingsStore: DurationProviding {
    private(set) var settings: TimerSettings
    // The composition root creates the store before TimerEngine, then assigns this reference.
    weak var engine: TimerEngine?

    private let persister: any SettingsPersisting
    private let presetTable: [Preset: PhaseDurations] = [
        .classic: PhaseDurations(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15),
        .deep: PhaseDurations(focusMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30),
        .short: PhaseDurations(focusMinutes: 15, shortBreakMinutes: 3, longBreakMinutes: 15)
    ]

    init(
        persister: any SettingsPersisting = UserDefaultsSettingsStore(),
        engine: TimerEngine? = nil
    ) {
        self.persister = persister
        settings = persister.load() ?? TimerSettings()
        self.engine = engine
        engine?.autoStartNext = settings.autoStartNext
    }

    func duration(for phase: Phase) -> Int {
        settings.durations.seconds(for: phase)
    }

    func adjustDuration(
        _ keyPath: WritableKeyPath<PhaseDurations, Int>,
        delta: Int,
        in range: ClosedRange<Int>,
        affecting phase: Phase
    ) {
        settings.durations[keyPath: keyPath] = min(range.upperBound, max(range.lowerBound, settings.durations[keyPath: keyPath] + delta))
        settings.preset = .custom
        persister.save(settings)
        syncIdleDuration(for: phase)
    }

    func cyclePreset() {
        let presets = Preset.allCases
        let next = presets[(presets.firstIndex(of: settings.preset)! + 1) % presets.count]
        settings.preset = next
        if let durations = presetTable[next] { settings.durations = durations }
        persister.save(settings)
        syncIdleDuration(for: engine?.phase)
    }

    func toggleSound() {
        settings.soundOn.toggle()
        persister.save(settings)
    }

    func toggleHaptics() {
        settings.hapticsOn.toggle()
        persister.save(settings)
    }

    func toggleAutoStart() {
        settings.autoStartNext.toggle()
        engine?.autoStartNext = settings.autoStartNext
        persister.save(settings)
    }

    private func syncIdleDuration(for phase: Phase?) {
        guard let phase else { return }
        engine?.syncIdleDuration(ifCurrentPhaseIs: phase, seconds: duration(for: phase))
    }
}
