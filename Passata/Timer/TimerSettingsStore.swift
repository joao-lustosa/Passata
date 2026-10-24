import Observation

struct PendingDurationChange {
    let phase: Phase
    let isResetToDefaults: Bool
    let apply: (inout TimerSettings) -> Void
}

enum DurationChangeRule {
    static func requiresConfirmation(
        changing phase: Phase,
        to newSeconds: Int,
        enginePhase: Phase,
        status: RunStatus,
        capturedDuration: Int
    ) -> Bool {
        guard status == .running || status == .paused, phase == enginePhase else { return false }
        return newSeconds != capturedDuration
    }
}

@Observable final class TimerSettingsStore: DurationProviding {
    private(set) var settings: TimerSettings
    private(set) var pendingDurationChange: PendingDurationChange?
    // The composition root creates the store before TimerEngine, then assigns this reference.
    weak var engine: TimerEngine?

    private let persister: any SettingsPersisting

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

    var sessionsPerCycle: Int { settings.sessionsPerCycle }

    func adjustDuration(
        _ keyPath: WritableKeyPath<PhaseDurations, Int>,
        delta: Int,
        in range: ClosedRange<Int>,
        affecting phase: Phase
    ) {
        let currentValue = settings.durations[keyPath: keyPath]
        let adjustment = currentValue.addingReportingOverflow(delta)
        let value = PhaseDurations.clamp(adjustment.overflow ? (delta < 0 ? Int.min : Int.max) : adjustment.partialValue,
                                         to: range)
        requestDurationChange(affecting: phase, newSeconds: value) { settings in
            settings.durations[keyPath: keyPath] = value
        }
    }

    @discardableResult
    func typeDuration(_ text: String, affecting phase: Phase) -> Bool {
        guard let seconds = DurationInputParsing.seconds(from: text, bounds: bounds(for: phase)) else { return false }
        requestDurationChange(affecting: phase, newSeconds: seconds) { settings in
            settings.durations[keyPath: phase.durationsKeyPath] = seconds
        }
        return true
    }

    func adjustSessionsPerCycle(by delta: Int) {
        let adjustment = settings.sessionsPerCycle.addingReportingOverflow(delta)
        settings.sessionsPerCycle = PhaseDurations.clamp(
            adjustment.overflow ? (delta < 0 ? Int.min : Int.max) : adjustment.partialValue,
            to: DurationBounds.sessionsPerCycle
        )
        persistAndReanchor()
    }

    @discardableResult
    func typeSessionsPerCycle(_ text: String) -> Bool {
        guard let value = DurationInputParsing.sessionsPerCycle(from: text, bounds: DurationBounds.sessionsPerCycle) else {
            return false
        }
        settings.sessionsPerCycle = value
        persistAndReanchor()
        return true
    }

    func resetToDefaults() {
        var defaults = settings
        defaults.durations = .classic
        defaults.sessionsPerCycle = TimerSettings.classicSessionsPerCycle

        if let engine,
           DurationChangeRule.requiresConfirmation(
            changing: engine.phase,
            to: PhaseDurations.classic.seconds(for: engine.phase),
            enginePhase: engine.phase,
            status: engine.status,
            capturedDuration: engine.currentPhaseDuration
           ) {
            pendingDurationChange = PendingDurationChange(phase: engine.phase, isResetToDefaults: true) { settings in
                settings.durations = .classic
                settings.sessionsPerCycle = TimerSettings.classicSessionsPerCycle
            }
            return
        }

        settings = defaults
        persistAndReanchor(syncIdlePhase: engine?.phase)
    }

    func resolvePendingDurationChange(restartCurrentPhase: Bool) {
        guard let pending = pendingDurationChange else { return }
        var updated = settings
        pending.apply(&updated)
        settings = updated
        persister.save(settings)
        syncIdleDuration(for: pending.phase)

        if restartCurrentPhase,
           let engine,
           engine.phase == pending.phase,
           engine.status == .running || engine.status == .paused {
            engine.restartCurrentPhase()
        } else if engine?.status == .running {
            engine?.reanchorSchedule()
        }
        pendingDurationChange = nil
    }

    func cancelPendingDurationChange() {
        pendingDurationChange = nil
    }

    func toggleSound() {
        settings.soundOn.toggle()
        persister.save(settings)
    }

    func toggleHaptics() {
        settings.hapticsOn.toggle()
        persister.save(settings)
    }

    func toggleRespectSilentMode() {
        settings.respectSilentMode.toggle()
        persister.save(settings)
    }

    func toggleAutoStart() {
        settings.autoStartNext.toggle()
        engine?.autoStartNext = settings.autoStartNext
        persister.save(settings)
    }

    private func requestDurationChange(
        affecting phase: Phase,
        newSeconds: Int,
        apply: @escaping (inout TimerSettings) -> Void
    ) {
        if let engine,
           DurationChangeRule.requiresConfirmation(
            changing: phase,
            to: newSeconds,
            enginePhase: engine.phase,
            status: engine.status,
            capturedDuration: engine.currentPhaseDuration
           ) {
            pendingDurationChange = PendingDurationChange(phase: phase, isResetToDefaults: false, apply: apply)
            return
        }

        applyChange(affecting: phase, apply: apply)
    }

    private func applyChange(affecting phase: Phase?, apply: (inout TimerSettings) -> Void) {
        var updated = settings
        apply(&updated)
        settings = updated
        persister.save(settings)
        if let phase { syncIdleDuration(for: phase) }
        if engine?.status == .running { engine?.reanchorSchedule() }
    }

    private func persistAndReanchor(syncIdlePhase phase: Phase? = nil) {
        persister.save(settings)
        if let phase { syncIdleDuration(for: phase) }
        if engine?.status == .running { engine?.reanchorSchedule() }
    }

    private func syncIdleDuration(for phase: Phase) {
        engine?.syncIdleDuration(ifCurrentPhaseIs: phase, seconds: duration(for: phase))
    }

    private func bounds(for phase: Phase) -> ClosedRange<Int> {
        switch phase {
        case .focus: DurationBounds.focus
        case .shortBreak: DurationBounds.shortBreak
        case .longBreak: DurationBounds.longBreak
        }
    }
}
