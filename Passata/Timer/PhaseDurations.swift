struct PhaseDurations: Codable, Equatable {
    static let classic = PhaseDurations(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15)

    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int

    func seconds(for phase: Phase) -> Int {
        switch phase {
        case .focus: focusMinutes * 60
        case .shortBreak: shortBreakMinutes * 60
        case .longBreak: longBreakMinutes * 60
        }
    }
}
