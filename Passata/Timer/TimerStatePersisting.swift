protocol TimerStatePersisting {
    func load() -> TimerSnapshot?
    func save(_ snapshot: TimerSnapshot)
}

struct NoOpTimerStateStore: TimerStatePersisting {
    func load() -> TimerSnapshot? { nil }
    func save(_ snapshot: TimerSnapshot) {}
}
