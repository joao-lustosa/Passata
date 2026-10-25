import Foundation

struct UserDefaultsTimerStateStore: TimerStatePersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "app.passata.timer-state") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> TimerSnapshot? {
        guard let object = defaults.object(forKey: key) else { return nil }
        do {
            guard let data = object as? Data else {
                throw DecodingError.typeMismatch(
                    Data.self,
                    .init(codingPath: [], debugDescription: "Stored value is not Data")
                )
            }
            return try JSONDecoder().decode(TimerSnapshot.self, from: data)
        } catch {
            defaults.set(object, forKey: key + ".unreadable")
            #if DEBUG
            print("Passata: \(key) present but undecodable (\(error)); moved aside, running on defaults.")
            #endif
            return nil
        }
    }

    func save(_ snapshot: TimerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
