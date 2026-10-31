import Observation

struct PendingDurationChange {
    let phase: Phase
    let isResetToDefaults: Bool
    let apply: (inout TimerSettings) -> Void
}

private enum DurationChangeDecision {
    case applyToNextSession
    case restartCurrentPhase
}

private struct RememberedDurationChange {
    let phase: Phase
    let phaseOccurrenceID: Int
    let decision: DurationChangeDecision
}

enum DurationChangeRule {
    static func requiresConfirmation(
        changing phase: Phase,
        to newSeconds: Int,
        enginePhase: Phase,
        status: RunStatus,
        capturedDuration: Int,
        hasRememberedDecision: Bool = false
    ) -> Bool {
        guard !hasRememberedDecision,
              status == .running || status == .paused,
              phase == enginePhase else { return false }
        return newSeconds != capturedDuration
    }
}

@Observable final class TimerSettingsStore: DurationProviding {
    private(set) var settings: TimerSettings
    private(set) var pendingDurationChange: PendingDurationChange?
    // The composition root creates the store before TimerEngine, then assigns this reference.
    weak var engine: TimerEngine?

    private let persister: any SettingsPersisting
    private var rememberedDurationChange: RememberedDurationChange?

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
        let adjustedValue = adjustment.overflow ? (delta < 0 ? Int.min : Int.max) : adjustment.partialValue
        let value = adjustedValue.clamped(to: range)
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
        settings.sessionsPerCycle = (adjustment.overflow ? (delta < 0 ? Int.min : Int.max) : adjustment.partialValue)
            .clamped(to: DurationBounds.sessionsPerCycle)
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
        let defaults = TimerSettings()
        let decision = engine.flatMap { rememberedDecision(for: $0.phase) }
        if let engine,
           DurationChangeRule.requiresConfirmation(
            changing: engine.phase,
            to: PhaseDurations.classic.seconds(for: engine.phase),
            enginePhase: engine.phase,
            status: engine.status,
            capturedDuration: engine.currentPhaseDuration,
            hasRememberedDecision: decision != nil
           ) {
            pendingDurationChange = PendingDurationChange(phase: engine.phase, isResetToDefaults: true) { settings in
                settings.durations = defaults.durations
                settings.sessionsPerCycle = defaults.sessionsPerCycle
            }
            return
        }

        settings.durations = defaults.durations
        settings.sessionsPerCycle = defaults.sessionsPerCycle
        persistAndReanchor(syncIdlePhase: engine?.phase, decision: decision)
    }

    func resolvePendingDurationChange(restartCurrentPhase: Bool) {
        guard let pending = pendingDurationChange else { return }
        let decision: DurationChangeDecision = restartCurrentPhase ? .restartCurrentPhase : .applyToNextSession
        if let engine,
           engine.phase == pending.phase,
           engine.status == .running || engine.status == .paused {
            rememberedDurationChange = RememberedDurationChange(
                phase: pending.phase,
                phaseOccurrenceID: engine.phaseOccurrenceID,
                decision: decision
            )
        }
        var updated = settings
        pending.apply(&updated)
        settings = updated
        persister.save(settings)
        updateEngineAfterDurationChange(for: pending.phase, decision: decision)
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
        let decision = rememberedDecision(for: phase)
        if let engine,
           DurationChangeRule.requiresConfirmation(
            changing: phase,
            to: newSeconds,
            enginePhase: engine.phase,
            status: engine.status,
            capturedDuration: engine.currentPhaseDuration,
            hasRememberedDecision: decision != nil
           ) {
            pendingDurationChange = PendingDurationChange(phase: phase, isResetToDefaults: false, apply: apply)
            return
        }

        applyChange(affecting: phase, decision: decision, apply: apply)
    }

    private func applyChange(
        affecting phase: Phase,
        decision: DurationChangeDecision?,
        apply: (inout TimerSettings) -> Void
    ) {
        var updated = settings
        apply(&updated)
        settings = updated
        persister.save(settings)
        updateEngineAfterDurationChange(for: phase, decision: decision)
    }

    private func persistAndReanchor(
        syncIdlePhase phase: Phase? = nil,
        decision: DurationChangeDecision? = nil
    ) {
        persister.save(settings)
        updateEngineAfterDurationChange(for: phase, decision: decision)
    }

    private func syncIdleDuration(for phase: Phase) {
        engine?.syncIdleDuration(ifCurrentPhaseIs: phase, seconds: duration(for: phase))
    }

    private func rememberedDecision(for phase: Phase) -> DurationChangeDecision? {
        guard let engine,
              engine.phase == phase,
              engine.status == .running || engine.status == .paused,
              let rememberedDurationChange,
              rememberedDurationChange.phase == phase,
              rememberedDurationChange.phaseOccurrenceID == engine.phaseOccurrenceID else {
            return nil
        }
        return rememberedDurationChange.decision
    }

    private func updateEngineAfterDurationChange(for phase: Phase?, decision: DurationChangeDecision?) {
        if let phase { syncIdleDuration(for: phase) }
        guard let engine else { return }

        if let phase,
           phase == engine.phase,
           engine.status == .running || engine.status == .paused,
           let decision {
            switch decision {
            case .applyToNextSession:
                if engine.status == .running { engine.reanchorSchedule() }
            case .restartCurrentPhase:
                engine.restartCurrentPhase()
            }
        } else if engine.status == .running {
            engine.reanchorSchedule()
        }
    }

    private func bounds(for phase: Phase) -> ClosedRange<Int> {
        switch phase {
        case .focus: DurationBounds.focus
        case .shortBreak: DurationBounds.shortBreak
        case .longBreak: DurationBounds.longBreak
        }
    }
}
