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
        guard let object = defaults.object(forKey: key) else { return nil }
        do {
            guard let data = object as? Data else {
                throw DecodingError.typeMismatch(
                    Data.self,
                    .init(codingPath: [], debugDescription: "Stored value is not Data")
                )
            }
            return try JSONDecoder().decode(TimerSettings.self, from: data)
        } catch {
            defaults.set(object, forKey: key + ".unreadable")
            #if DEBUG
            print("Passata: \(key) present but undecodable (\(error)); moved aside, running on defaults.")
            #endif
            return nil
        }
    }

    func save(_ settings: TimerSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
