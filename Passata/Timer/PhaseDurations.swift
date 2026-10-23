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

extension PhaseDurations {
    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes)
            ?? Self.classic.focusMinutes
        shortBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes)
            ?? Self.classic.shortBreakMinutes
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes)
            ?? Self.classic.longBreakMinutes
    }
}
