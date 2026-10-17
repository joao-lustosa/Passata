import Foundation

struct UserDefaultsTimerStateStore: TimerStatePersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "app.passata.timer-state") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> TimerSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TimerSnapshot.self, from: data)
    }

    func save(_ snapshot: TimerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
