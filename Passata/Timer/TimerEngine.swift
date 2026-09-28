import Foundation
import Observation

@Observable final class TimerEngine {
    private(set) var phase: Phase
    private(set) var state: TimerRunState
    var status: RunStatus {
        switch state {
        case .idle: .idle
        case .running: .running
        case .paused: .paused
        case .complete: .complete
        }
    }
    private(set) var sessionIndex: Int
    nonisolated static let sessionsPerCycle = 4
    var sessionsPerCycle: Int { Self.sessionsPerCycle }
    // Stored so the macOS no-window timer loop triggers observation updates.
    private(set) var remainingSeconds: Int
    var autoStartNext = true
    var onPhaseCompleted: (() -> Void)?
    enum TransitionKind { case started, resumed, paused, completed, skipped, startedNext, reset }
    var onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TransitionKind) -> Void)?

    nonisolated(unsafe) private var autoAdvanceTask: Task<Void, Never>?
    private let durationProvider: any DurationProviding
    private let dateProvider: any DateProviding
    private let persister: any TimerStatePersisting

    init(
        durationProvider: any DurationProviding,
        dateProvider: any DateProviding = SystemDateProvider(),
        persister: any TimerStatePersisting = UserDefaultsTimerStateStore(),
        autoStartNext: Bool = true,
        onPhaseCompleted: (() -> Void)? = nil,
        onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TransitionKind) -> Void)? = nil
    ) {
        self.durationProvider = durationProvider
        self.dateProvider = dateProvider
        self.persister = persister
        self.autoStartNext = autoStartNext
        self.onPhaseCompleted = onPhaseCompleted
        self.onStateChange = onStateChange

        if let snapshot = persister.load() {
            phase = snapshot.phase
            state = TimerRunState(status: snapshot.status, endDate: snapshot.endDate, pausedRemaining: snapshot.pausedRemaining)
            sessionIndex = snapshot.sessionIndex
            remainingSeconds = 0
            if state == .idle {
                remainingSeconds = durationProvider.duration(for: phase)
            } else {
                recomputeRemaining()
            }
            checkForCompletion()
        } else {
            phase = .focus
            state = .idle
            sessionIndex = 1
            remainingSeconds = durationProvider.duration(for: .focus)
        }
    }

    deinit { autoAdvanceTask?.cancel() }

    func start() {
        guard state == .idle else { return }
        state = .running(endDate: dateProvider.now.addingTimeInterval(TimeInterval(durationProvider.duration(for: phase))))
        persist()
        emitStateChange(.started)
    }

    func resume() {
        guard case .paused(let remaining) = state else { return }
        state = .running(endDate: dateProvider.now.addingTimeInterval(remaining))
        recomputeRemaining()
        persist()
        emitStateChange(.resumed)
    }

    func pause() {
        guard case .running(let endDate) = state else { return }
        state = .paused(remaining: max(0, endDate.timeIntervalSince(dateProvider.now)))
        recomputeRemaining()
        persist()
        emitStateChange(.paused)
    }

    func togglePrimary() {
        switch status {
        case .idle: start()
        case .paused: resume()
        case .running: pause()
        case .complete: break
        }
    }

    func onReset() {
        guard state != .idle else { return }
        autoAdvanceTask?.cancel()
        let fullDuration = durationProvider.duration(for: phase)
        state = .idle
        remainingSeconds = fullDuration
        persist()
        emitStateChange(.reset)
    }

    func onSkip() {
        autoAdvanceTask?.cancel()
        transitionToNextPhase(autoStart: false)
        emitStateChange(.skipped)
    }

    func onStartNext() {
        autoAdvanceTask?.cancel()
        transitionToNextPhase(autoStart: true)
        emitStateChange(.startedNext)
    }

    func recomputeRemaining() {
        switch state {
        case .running(let endDate):
            remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(dateProvider.now))))
        case .paused(let remaining):
            remainingSeconds = max(0, Int(ceil(remaining)))
        case .idle, .complete:
            break
        }
    }

    func checkForCompletion() {
        guard case .running(let endDate) = state, endDate.timeIntervalSince(dateProvider.now) <= 0 else { return }
        remainingSeconds = 0
        state = .complete
        onPhaseCompleted?()
        persist()
        scheduleAutoAdvanceIfNeeded()
        emitStateChange(.completed)
    }

    func syncIdleDuration(ifCurrentPhaseIs phase: Phase, seconds: Int) {
        guard status == .idle, self.phase == phase else { return }
        remainingSeconds = seconds
    }

    private func transitionToNextPhase(autoStart: Bool) {
        let next = phase.next(sessionIndex: sessionIndex, sessionsPerCycle: sessionsPerCycle)
        phase = next.phase
        sessionIndex = next.sessionIndex
        let fullDuration = durationProvider.duration(for: phase)
        remainingSeconds = fullDuration
        state = autoStart ? .running(endDate: dateProvider.now.addingTimeInterval(TimeInterval(fullDuration))) : .idle
        persist()
    }

    private func emitStateChange(_ kind: TransitionKind) {
        onStateChange?(phase, sessionIndex, currentRenderState, kind)
    }

    var currentRenderState: RenderState {
        switch state {
        case .running(let phaseEnd):
            let phaseStart = phaseEnd.addingTimeInterval(-TimeInterval(durationProvider.duration(for: phase)))
            return .running(phaseStart: phaseStart, phaseEnd: phaseEnd)
        case .idle:
            return .idle(phaseDurationSeconds: durationProvider.duration(for: phase))
        case .paused(let remaining):
            return .paused(
                remainingSeconds: Int(ceil(remaining)),
                phaseDurationSeconds: durationProvider.duration(for: phase)
            )
        case .complete:
            return .complete
        }
    }

    private func scheduleAutoAdvanceIfNeeded() {
        guard autoStartNext, phase != .longBreak else { return }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let self, self.status == .complete else { return }
            self.onStartNext()
        }
    }

    private func persist() {
        let (status, endDate, pausedRemaining) = state.snapshotFields
        persister.save(TimerSnapshot(phase: phase, status: status, sessionIndex: sessionIndex, endDate: endDate, pausedRemaining: pausedRemaining))
    }
}
