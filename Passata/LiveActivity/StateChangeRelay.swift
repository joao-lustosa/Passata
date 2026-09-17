/// Bridges synchronous state-change callbacks into an actor's serial event processing.
/// Submission is safe from any context, and events yield in submission order.
nonisolated final class StateChangeRelay: Sendable {
    let events: AsyncStream<StateChangeEvent>
    private let continuation: AsyncStream<StateChangeEvent>.Continuation

    init() {
        (events, continuation) = AsyncStream<StateChangeEvent>.makeStream()
    }

    func submit(_ event: StateChangeEvent) {
        continuation.yield(event)
    }
}
