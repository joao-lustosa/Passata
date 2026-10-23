struct TimerSettings: Codable, Equatable {
    var durations = PhaseDurations.classic
    var preset: Preset = .classic
    var autoStartNext = true
    var soundOn = true
    var hapticsOn = true
}

extension TimerSettings {
    private enum CodingKeys: String, CodingKey {
        case durations, preset, autoStartNext, soundOn, hapticsOn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        durations = try container.decodeIfPresent(PhaseDurations.self, forKey: .durations) ?? .classic
        preset = try container.decodeIfPresent(Preset.self, forKey: .preset) ?? .classic
        autoStartNext = try container.decodeIfPresent(Bool.self, forKey: .autoStartNext) ?? true
        soundOn = try container.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        hapticsOn = try container.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? true
    }
}
