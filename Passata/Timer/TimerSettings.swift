struct TimerSettings: Codable, Equatable {
    var durations = PhaseDurations.classic
    var sessionsPerCycle = Self.classicSessionsPerCycle
    var autoStartNext = true
    var soundOn = true
    var hapticsOn = true
    var respectSilentMode = true
}

extension TimerSettings {
    nonisolated static let classicSessionsPerCycle = 4

    private enum CodingKeys: String, CodingKey {
        case durations, sessionsPerCycle, autoStartNext, soundOn, hapticsOn, respectSilentMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TimerSettings()
        durations = try container.decodeIfPresent(PhaseDurations.self, forKey: .durations) ?? defaults.durations
        sessionsPerCycle = (
            try container.decodeIfPresent(Int.self, forKey: .sessionsPerCycle) ?? defaults.sessionsPerCycle
        ).clamped(
            to: DurationBounds.sessionsPerCycle
        )
        autoStartNext = try container.decodeIfPresent(Bool.self, forKey: .autoStartNext) ?? defaults.autoStartNext
        soundOn = try container.decodeIfPresent(Bool.self, forKey: .soundOn) ?? defaults.soundOn
        hapticsOn = try container.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? defaults.hapticsOn
        respectSilentMode = try container.decodeIfPresent(Bool.self, forKey: .respectSilentMode)
            ?? defaults.respectSilentMode
    }
}
