struct PhaseDurations: Codable, Equatable {
    static let classic = PhaseDurations(focusSeconds: 25 * 60, shortBreakSeconds: 5 * 60, longBreakSeconds: 15 * 60)

    var focusSeconds: Int
    var shortBreakSeconds: Int
    var longBreakSeconds: Int

    func seconds(for phase: Phase) -> Int {
        self[keyPath: phase.durationsKeyPath]
    }
}

extension Phase {
    var durationsKeyPath: WritableKeyPath<PhaseDurations, Int> {
        switch self {
        case .focus: \.focusSeconds
        case .shortBreak: \.shortBreakSeconds
        case .longBreak: \.longBreakSeconds
        }
    }
}

extension PhaseDurations {
    private enum CodingKeys: String, CodingKey {
        case focusSeconds, shortBreakSeconds, longBreakSeconds
    }

    private enum LegacyKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyKeys.self)
        focusSeconds = try Self.decodeDuration(
            from: container,
            legacyContainer: legacyContainer,
            currentKey: .focusSeconds,
            legacyKey: .focusMinutes,
            defaultValue: Self.classic.focusSeconds,
            bounds: DurationBounds.focus
        )
        shortBreakSeconds = try Self.decodeDuration(
            from: container,
            legacyContainer: legacyContainer,
            currentKey: .shortBreakSeconds,
            legacyKey: .shortBreakMinutes,
            defaultValue: Self.classic.shortBreakSeconds,
            bounds: DurationBounds.shortBreak
        )
        longBreakSeconds = try Self.decodeDuration(
            from: container,
            legacyContainer: legacyContainer,
            currentKey: .longBreakSeconds,
            legacyKey: .longBreakMinutes,
            defaultValue: Self.classic.longBreakSeconds,
            bounds: DurationBounds.longBreak
        )
    }

    private static func decodeDuration(
        from container: KeyedDecodingContainer<CodingKeys>,
        legacyContainer: KeyedDecodingContainer<LegacyKeys>,
        currentKey: CodingKeys,
        legacyKey: LegacyKeys,
        defaultValue: Int,
        bounds: ClosedRange<Int>
    ) throws -> Int {
        if let seconds = try container.decodeIfPresent(Int.self, forKey: currentKey) {
            return seconds.clamped(to: bounds)
        }
        if let minutes = try legacyContainer.decodeIfPresent(Int.self, forKey: legacyKey) {
            let conversion = minutes.multipliedReportingOverflow(by: 60)
            return (conversion.overflow ? (minutes < 0 ? Int.min : Int.max) : conversion.partialValue).clamped(to: bounds)
        }
        return defaultValue.clamped(to: bounds)
    }
}

enum DurationBounds {
    static let focus = 30...10_800
    static let shortBreak = 30...3_600
    static let longBreak = 30...3_600
    static let sessionsPerCycle = 1...12
    static let stepSeconds = 60
}
