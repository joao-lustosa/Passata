import Foundation
import Testing
@testable import Passata

@Test
@MainActor
func currentTimerSettingsShapeDecodesWithoutChangingValues() throws {
    let json = Data(#"{"durations":{"focusMinutes":42,"shortBreakMinutes":7,"longBreakMinutes":20},"preset":"deep","autoStartNext":false,"soundOn":false,"hapticsOn":false}"#.utf8)

    let settings = try JSONDecoder().decode(TimerSettings.self, from: json)

    #expect(settings.durations == PhaseDurations(focusMinutes: 42, shortBreakMinutes: 7, longBreakMinutes: 20))
    #expect(settings.preset == .deep)
    #expect(settings.autoStartNext == false)
    #expect(settings.soundOn == false)
    #expect(settings.hapticsOn == false)
}

@Test
@MainActor
func timerSettingsEncodingRoundTrips() throws {
    var expected = TimerSettings()
    expected.durations = PhaseDurations(focusMinutes: 42, shortBreakMinutes: 7, longBreakMinutes: 20)
    expected.preset = .deep
    expected.autoStartNext = false
    expected.soundOn = false
    expected.hapticsOn = false

    let decoded = try JSONDecoder().decode(TimerSettings.self, from: JSONEncoder().encode(expected))

    #expect(decoded == expected)
}

@Test
@MainActor
func everyMissingTimerSettingsFieldDefaultsIndependently() throws {
    let json = Data(#"{"durations":{"focusMinutes":42,"shortBreakMinutes":7,"longBreakMinutes":20},"preset":"deep","autoStartNext":false,"soundOn":false,"hapticsOn":false}"#.utf8)
    let decoder = JSONDecoder()
    let classic = TimerSettings()

    var topLevelCases: [(String, (inout TimerSettings) -> Void)] = [
        ("preset", { $0.preset = classic.preset }),
        ("autoStartNext", { $0.autoStartNext = classic.autoStartNext }),
        ("soundOn", { $0.soundOn = classic.soundOn }),
        ("hapticsOn", { $0.hapticsOn = classic.hapticsOn })
    ]
    topLevelCases.insert(("durations", { $0.durations = classic.durations }), at: 0)

    let originalObject = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
    for (key, applyDefault) in topLevelCases {
        var object = originalObject
        object.removeValue(forKey: key)
        let data = try JSONSerialization.data(withJSONObject: object)
        let actual = try decoder.decode(TimerSettings.self, from: data)
        var expected = try decoder.decode(TimerSettings.self, from: json)
        applyDefault(&expected)
        #expect(actual == expected)
    }

    for key in ["focusMinutes", "shortBreakMinutes", "longBreakMinutes"] {
        var object = originalObject
        var durations = try #require(object["durations"] as? [String: Any])
        durations.removeValue(forKey: key)
        object["durations"] = durations
        let actual = try decoder.decode(TimerSettings.self, from: JSONSerialization.data(withJSONObject: object))
        var expected = try decoder.decode(TimerSettings.self, from: json)
        switch key {
        case "focusMinutes": expected.durations.focusMinutes = classic.durations.focusMinutes
        case "shortBreakMinutes": expected.durations.shortBreakMinutes = classic.durations.shortBreakMinutes
        case "longBreakMinutes": expected.durations.longBreakMinutes = classic.durations.longBreakMinutes
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
    #expect(decoded.preset == .classic)
    #expect(decoded.autoStartNext)
    #expect(decoded.hapticsOn)
}
