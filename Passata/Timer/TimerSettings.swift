struct TimerSettings: Codable, Equatable {
    var durations = PhaseDurations(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15)
    var preset: Preset = .classic
    var autoStartNext = true
    var soundOn = true
    var hapticsOn = true
}
