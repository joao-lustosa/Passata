protocol DurationProviding {
    func duration(for phase: Phase) -> Int
    var sessionsPerCycle: Int { get }
}

extension DurationProviding {
    var sessionsPerCycle: Int { TimerSettings.classicSessionsPerCycle }
}
