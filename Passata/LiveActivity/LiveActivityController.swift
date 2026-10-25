import Foundation

actor LiveActivityController {
    private let publisher: any LiveActivityPublishing
    private let relay = StateChangeRelay<StateChangeEvent>()

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
        sessionsPerCycle: Int,
        render: RenderState,
        kind: TimerEngine.TransitionKind,
        autoStartNext: Bool
    ) {
        relay.submit(StateChangeEvent(
            phase: phase,
            sessionIndex: sessionIndex,
            sessionsPerCycle: sessionsPerCycle,
            render: render,
            kind: kind,
            autoStartNext: autoStartNext
        ))
    }

    private func handle(_ event: StateChangeEvent) async {
        let content = PassataActivityAttributes.ContentState(
            phase: event.phase,
            sessionIndex: event.sessionIndex,
            sessionsPerCycle: event.sessionsPerCycle,
            render: event.render
        )
        let staleDate: Date? = {
            if case .running(_, let phaseEnd) = event.render { return phaseEnd }
            return nil
        }()

        switch event.kind {
        case .started, .startedNext:
            await reconcileActiveActivity(content, staleDate: staleDate, status: .running)
        case .resumed, .paused, .reanchored:
            await publisher.update(content, staleDate: staleDate)
        case .completed where !event.autoStartNext, .skipped, .reset:
            await publisher.endImmediately(content)
        case .completed:
            await publisher.update(content, staleDate: staleDate)
        case .reconciled:
            let status: RunStatus = if case .running = event.render { .running } else { .complete }
            await reconcileActiveActivity(content, staleDate: staleDate, status: status)
        }
    }

    func reconcileOnLaunch(
        phase: Phase,
        sessionIndex: Int,
        sessionsPerCycle: Int,
        status: RunStatus,
        render: RenderState
    ) async {
        let exists = await publisher.hasActiveActivity()
        let content = PassataActivityAttributes.ContentState(
            phase: phase,
            sessionIndex: sessionIndex,
            sessionsPerCycle: sessionsPerCycle,
            render: render
        )
        let staleDate: Date? = {
            if case .running(_, let phaseEnd) = render { return phaseEnd }
            return nil
        }()

        await reconcileActiveActivity(content, staleDate: staleDate, status: status, exists: exists)
    }

    private func reconcileActiveActivity(
        _ content: PassataActivityAttributes.ContentState,
        staleDate: Date?,
        status: RunStatus,
        exists knownActivityState: Bool? = nil
    ) async {
        let exists: Bool
        if let knownActivityState {
            exists = knownActivityState
        } else {
            exists = await publisher.hasActiveActivity()
        }

        switch status {
        case .idle, .complete:
            if exists { await publisher.endImmediately(content) }
        case .running, .paused:
            if exists {
                await publisher.update(content, staleDate: staleDate)
            } else {
                do {
                    try publisher.request(content, staleDate: staleDate)
                } catch {
                    // Live Activities may be disabled or unauthorized; the timer remains unaffected.
                }
            }
        }
    }
}
