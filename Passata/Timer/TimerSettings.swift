struct TimerSettings: Codable, Equatable {
    var durations = PhaseDurations.classic
    var preset: Preset = .classic
    var autoStartNext = true
    var soundOn = true
    var hapticsOn = true
}
