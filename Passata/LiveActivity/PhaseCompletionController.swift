import Foundation

actor PhaseCompletionController {
    private let notifier: any PhaseCompletionNotifying
    private let relay = StateChangeRelay<PhaseCompletionEvent>()

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
        sessionsPerCycle: Int,
        render: RenderState,
        kind: TimerEngine.TransitionKind,
        autoStartNext: Bool,
        upcomingBoundaries: [PhaseBoundary]
    ) {
        let stateChange = StateChangeEvent(
            phase: phase,
            sessionIndex: sessionIndex,
            sessionsPerCycle: sessionsPerCycle,
            render: render,
            kind: kind,
            autoStartNext: autoStartNext
        )
        relay.submit(PhaseCompletionEvent(stateChange: stateChange, upcomingBoundaries: upcomingBoundaries))
    }

    private func handle(_ event: PhaseCompletionEvent) async {
        switch event.stateChange.kind {
        case .started, .resumed, .startedNext, .reanchored:
            guard case .running = event.stateChange.render else { return }
            await notifier.scheduleChain(event.upcomingBoundaries)
        case .reconciled:
            guard case .running = event.stateChange.render else {
                await notifier.cancelPending()
                return
            }
            await notifier.scheduleChain(event.upcomingBoundaries)
        case .completed where event.stateChange.autoStartNext:
            break
        case .paused, .reset, .skipped, .completed:
            await notifier.cancelPending()
        }
    }
}

nonisolated private struct PhaseCompletionEvent: Sendable {
    let stateChange: StateChangeEvent
    let upcomingBoundaries: [PhaseBoundary]
}
