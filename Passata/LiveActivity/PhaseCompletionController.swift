import Foundation

actor PhaseCompletionController {
    private let notifier: any PhaseCompletionNotifying
    private let events: AsyncStream<StateChangeEvent>
    private let continuation: AsyncStream<StateChangeEvent>.Continuation

    struct StateChangeEvent {
        let phase: Phase
        let sessionIndex: Int
        let render: RenderState
        let kind: TimerEngine.TransitionKind
    }

    init(notifier: any PhaseCompletionNotifying = SystemPhaseCompletionNotifier()) {
        self.notifier = notifier
        (events, continuation) = AsyncStream<StateChangeEvent>.makeStream()
        Task { [weak self] in
            guard let self else { return }
            for await event in self.events {
                await self.handle(event)
            }
        }
    }

    nonisolated func submit(
        phase: Phase,
        sessionIndex: Int,
        render: RenderState,
        kind: TimerEngine.TransitionKind
    ) {
        continuation.yield(StateChangeEvent(phase: phase, sessionIndex: sessionIndex, render: render, kind: kind))
    }

    private func handle(_ event: StateChangeEvent) async {
        switch event.kind {
        case .started, .resumed, .startedNext:
            guard case .running(_, let phaseEnd) = event.render else { return }
            await notifier.schedule(at: phaseEnd, phase: event.phase)
        case .paused, .reset, .skipped, .completed:
            await notifier.cancelPending()
        }
    }
}
