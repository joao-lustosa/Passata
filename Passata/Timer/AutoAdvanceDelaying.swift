protocol AutoAdvanceDelaying: Sendable {
    nonisolated func wait() async throws
}

nonisolated struct SystemAutoAdvanceDelay: AutoAdvanceDelaying {
    func wait() async throws {
        try await Task.sleep(for: .seconds(1.4))
    }
}
