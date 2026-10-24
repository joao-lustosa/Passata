import Foundation
import Testing
@testable import Passata

@Test
@MainActor
func preEditableDurationsBlobMigratesMinutesAndIgnoresPreset() throws {
    let preChangeSettingsBlob = Data(
        #"{"durations":{"focusMinutes":42,"shortBreakMinutes":7,"longBreakMinutes":20},"preset":"deep","autoStartNext":false,"soundOn":false,"hapticsOn":false}"#.utf8
    )

    let settings = try JSONDecoder().decode(TimerSettings.self, from: preChangeSettingsBlob)

    #expect(settings.durations == PhaseDurations(focusSeconds: 42 * 60, shortBreakSeconds: 7 * 60, longBreakSeconds: 20 * 60))
    #expect(settings.sessionsPerCycle == TimerSettings.classicSessionsPerCycle)
    #expect(settings.autoStartNext == false)
    #expect(settings.soundOn == false)
    #expect(settings.hapticsOn == false)
    #expect(settings.respectSilentMode)
}

@Test
@MainActor
func preEditableSettingsBlobLoadsThroughUserDefaultsStore() throws {
    let suite = "PassataTests.LegacyEditableDurations." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "timer-settings"
    defaults.set(
        Data(#"{"durations":{"focusMinutes":42,"shortBreakMinutes":7,"longBreakMinutes":20},"preset":"deep"}"#.utf8),
        forKey: key
    )

    let store = TimerSettingsStore(persister: UserDefaultsSettingsStore(defaults: defaults, key: key))

    #expect(store.settings.durations == PhaseDurations(focusSeconds: 2_520, shortBreakSeconds: 420, longBreakSeconds: 1_200))
    #expect(store.settings.sessionsPerCycle == TimerSettings.classicSessionsPerCycle)
}

@Test
@MainActor
func legacyDurationsAreClampedAfterConversion() throws {
    let oldSettings = Data(#"{"durations":{"focusMinutes":250,"shortBreakMinutes":0,"longBreakMinutes":20},"preset":"classic"}"#.utf8)

    let settings = try JSONDecoder().decode(TimerSettings.self, from: oldSettings)

    #expect(settings.durations.focusSeconds == DurationBounds.focus.upperBound)
    #expect(settings.durations.shortBreakSeconds == DurationBounds.shortBreak.lowerBound)
    #expect(settings.durations.longBreakSeconds == 20 * 60)
}

@Test
@MainActor
func sessionsPerCycleIsClampedWhenDecoded() throws {
    let outOfRangeValues = [(0, DurationBounds.sessionsPerCycle.lowerBound),
                            (13, DurationBounds.sessionsPerCycle.upperBound)]
    for (storedValue, expectedValue) in outOfRangeValues {
        let settings = try JSONDecoder().decode(
            TimerSettings.self,
            from: Data("{\"sessionsPerCycle\":\(storedValue)}".utf8)
        )

        #expect(settings.sessionsPerCycle == expectedValue)
    }
}

@Test
@MainActor
func timerSettingsEncodingRoundTrips() throws {
    var expected = TimerSettings()
    expected.durations = PhaseDurations(focusSeconds: 2_522, shortBreakSeconds: 445, longBreakSeconds: 1_202)
    expected.sessionsPerCycle = 7
    expected.autoStartNext = false
    expected.soundOn = false
    expected.hapticsOn = false

    let decoded = try JSONDecoder().decode(TimerSettings.self, from: JSONEncoder().encode(expected))

    #expect(decoded == expected)
}

@Test
@MainActor
func everyMissingTimerSettingsFieldDefaultsIndependently() throws {
    let json = Data(#"{"durations":{"focusSeconds":2520,"shortBreakSeconds":420,"longBreakSeconds":1200},"sessionsPerCycle":6,"autoStartNext":false,"soundOn":false,"hapticsOn":false,"respectSilentMode":false}"#.utf8)
    let decoder = JSONDecoder()
    let defaults = TimerSettings()
    let originalObject = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])

    let topLevelCases: [(String, (inout TimerSettings) -> Void)] = [
        ("sessionsPerCycle", { $0.sessionsPerCycle = defaults.sessionsPerCycle }),
        ("autoStartNext", { $0.autoStartNext = defaults.autoStartNext }),
        ("soundOn", { $0.soundOn = defaults.soundOn }),
        ("hapticsOn", { $0.hapticsOn = defaults.hapticsOn }),
        ("respectSilentMode", { $0.respectSilentMode = defaults.respectSilentMode }),
        ("durations", { $0.durations = defaults.durations })
    ]

    for (key, applyDefault) in topLevelCases {
        var object = originalObject
        object.removeValue(forKey: key)
        let actual = try decoder.decode(TimerSettings.self, from: JSONSerialization.data(withJSONObject: object))
        var expected = try decoder.decode(TimerSettings.self, from: json)
        applyDefault(&expected)
        #expect(actual == expected)
    }

    for key in ["focusSeconds", "shortBreakSeconds", "longBreakSeconds"] {
        var object = originalObject
        var durations = try #require(object["durations"] as? [String: Any])
        durations.removeValue(forKey: key)
        object["durations"] = durations
        let actual = try decoder.decode(TimerSettings.self, from: JSONSerialization.data(withJSONObject: object))
        var expected = try decoder.decode(TimerSettings.self, from: json)
        switch key {
        case "focusSeconds": expected.durations.focusSeconds = defaults.durations.focusSeconds
        case "shortBreakSeconds": expected.durations.shortBreakSeconds = defaults.durations.shortBreakSeconds
        case "longBreakSeconds": expected.durations.longBreakSeconds = defaults.durations.longBreakSeconds
        default: Issue.record("Unexpected duration key: \(key)")
        }
        #expect(actual == expected)
    }
}

@Test(arguments: [
    "not stored as Data",
    Data("not JSON".utf8)
] as [any Sendable])
@MainActor
func malformedSettingsArePreservedAndCanBeReplacedByAnOrdinarySave(_ value: any Sendable) throws {
    let suite = "PassataTests.SettingsCorruption." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "timer-settings"
    defaults.set(value, forKey: key)
    let persister = UserDefaultsSettingsStore(defaults: defaults, key: key)
    let store = TimerSettingsStore(persister: persister)

    store.toggleSound()

    let archived = try #require(defaults.object(forKey: key + ".unreadable"))
    #expect((archived as? Data) == (value as? Data))
    #expect((archived as? String) == (value as? String))
    let replacement = try #require(defaults.data(forKey: key))
    let decoded = try JSONDecoder().decode(TimerSettings.self, from: replacement)
    #expect(decoded.soundOn == false)
    #expect(decoded.durations == .classic)
    #expect(decoded.sessionsPerCycle == TimerSettings.classicSessionsPerCycle)
    #expect(decoded.autoStartNext)
    #expect(decoded.hapticsOn)
}
