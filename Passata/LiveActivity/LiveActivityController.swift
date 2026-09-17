import Foundation

actor LiveActivityController {
    private let publisher: any LiveActivityPublishing
    private let relay = StateChangeRelay()

    init(publisher: any LiveActivityPublishing = SystemLiveActivityPublisher()) {
        self.publisher = publisher
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
        let content = PassataActivityAttributes.ContentState(
            phase: event.phase,
            sessionIndex: event.sessionIndex,
            sessionsPerCycle: TimerEngine.sessionsPerCycle,
            render: event.render
        )
        let staleDate: Date? = {
            if case .running(_, let phaseEnd) = event.render { return phaseEnd }
            return nil
        }()

        switch event.kind {
        case .started:
            do {
                try publisher.request(content, staleDate: staleDate)
            } catch {
                // Live Activities may be disabled or unauthorized; the timer remains unaffected.
            }
        case .resumed, .paused, .completed, .skipped, .startedNext:
            await publisher.update(content, staleDate: staleDate)
        case .reset:
            await publisher.endImmediately(content)
        }
    }

    func reconcileOnLaunch(
        phase: Phase,
        sessionIndex: Int,
        status: RunStatus,
        render: RenderState
    ) async {
        let exists = await publisher.hasActiveActivity()
        let content = PassataActivityAttributes.ContentState(
            phase: phase,
            sessionIndex: sessionIndex,
            sessionsPerCycle: TimerEngine.sessionsPerCycle,
            render: render
        )
        let staleDate: Date? = {
            if case .running(_, let phaseEnd) = render { return phaseEnd }
            return nil
        }()

        switch (status, exists) {
        case (.idle, true):
            await publisher.endImmediately(content)
        case (.idle, false):
            break
        case (_, true):
            await publisher.update(content, staleDate: staleDate)
        case (_, false):
            do {
                try publisher.request(content, staleDate: staleDate)
            } catch {
                // Live Activities may be disabled or unauthorized; degrade silently.
            }
        }
    }
}
