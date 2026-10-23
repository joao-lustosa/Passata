/// Bridges synchronous state-change callbacks into an actor's serial event processing.
/// Submission is safe from any context, and events yield in submission order.
nonisolated final class StateChangeRelay<Event: Sendable>: Sendable {
    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    init() {
        (events, continuation) = AsyncStream<Event>.makeStream()
    }

    func submit(_ event: Event) {
        continuation.yield(event)
    }
}
