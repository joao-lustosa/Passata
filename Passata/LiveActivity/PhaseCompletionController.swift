import Foundation

actor PhaseCompletionController {
    private let notifier: any PhaseCompletionNotifying
    private let relay = StateChangeRelay()

    init(notifier: any PhaseCompletionNotifying = SystemPhaseCompletionNotifier()) {
        self.notifier = notifier
        let relay = relay
        Task { [weak self] in
            for await event in relay.events {
                guard let self else { return }
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
        relay.submit(StateChangeEvent(phase: phase, sessionIndex: sessionIndex, render: render, kind: kind))
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
