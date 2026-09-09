import Foundation

protocol SettingsPersisting {
    func load() -> TimerSettings?
    func save(_ settings: TimerSettings)
}

struct UserDefaultsSettingsStore: SettingsPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "app.passata.timer-settings") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> TimerSettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TimerSettings.self, from: data)
    }

    func save(_ settings: TimerSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
