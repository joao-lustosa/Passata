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
        durations = try container.decodeIfPresent(PhaseDurations.self, forKey: .durations) ?? .classic
        sessionsPerCycle = PhaseDurations.clamp(
            try container.decodeIfPresent(Int.self, forKey: .sessionsPerCycle) ?? Self.classicSessionsPerCycle,
            to: DurationBounds.sessionsPerCycle
        )
        autoStartNext = try container.decodeIfPresent(Bool.self, forKey: .autoStartNext) ?? true
        soundOn = try container.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        hapticsOn = try container.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? true
        respectSilentMode = try container.decodeIfPresent(Bool.self, forKey: .respectSilentMode) ?? true
    }
}
