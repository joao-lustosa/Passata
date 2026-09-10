import Foundation
import Observation

@Observable final class TimerEngine {
    private(set) var phase: Phase
    private(set) var status: RunStatus
    private(set) var sessionIndex: Int
    let sessionsPerCycle = 4
    private(set) var remainingSeconds: Int
    private var endDate: Date?
    private var pausedRemaining: TimeInterval?
    var autoStartNext = true
    var onPhaseCompleted: (() -> Void)?
    enum TransitionKind { case started, resumed, paused, completed, skipped, startedNext, reset }
    var onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TransitionKind) -> Void)?

    private var autoAdvanceTask: Task<Void, Never>?
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
            status = snapshot.status
            sessionIndex = snapshot.sessionIndex
            endDate = snapshot.endDate
            pausedRemaining = snapshot.pausedRemaining
            // Definite-initialization placeholder; the two calls below immediately derive it.
            remainingSeconds = 0
            recomputeRemaining()
            checkForCompletion()
        } else {
            phase = .focus
            status = .idle
            sessionIndex = 1
            remainingSeconds = durationProvider.duration(for: .focus)
            endDate = nil
            pausedRemaining = TimeInterval(remainingSeconds)
        }
    }

    deinit { autoAdvanceTask?.cancel() }

    func start() {
        guard status == .idle else { return }
        pausedRemaining = nil
        endDate = dateProvider.now.addingTimeInterval(TimeInterval(durationProvider.duration(for: phase)))
        status = .running
        persist()
        emitStateChange(.started)
    }

    func resume() {
        guard status == .paused else { return }
        let remaining = pausedRemaining ?? 0
        endDate = dateProvider.now.addingTimeInterval(remaining)
        pausedRemaining = nil
        status = .running
        recomputeRemaining()
        persist()
        emitStateChange(.resumed)
    }

    func pause() {
        guard status == .running else { return }
        pausedRemaining = max(0, endDate?.timeIntervalSince(dateProvider.now) ?? 0)
        endDate = nil
        status = .paused
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
        guard status != .idle else { return }
        autoAdvanceTask?.cancel()
        let fullDuration = durationProvider.duration(for: phase)
        status = .idle
        endDate = nil
        pausedRemaining = TimeInterval(fullDuration)
        remainingSeconds = fullDuration
        persist()
        emitStateChange(.reset)
    }

    func onSkip() {
        autoAdvanceTask?.cancel()
        transitionToNextPhase(status: .idle)
        emitStateChange(.skipped)
    }

    func onStartNext() {
        autoAdvanceTask?.cancel()
        transitionToNextPhase(status: .running)
        emitStateChange(.startedNext)
    }

    func recomputeRemaining() {
        if status == .running, let endDate {
            remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(dateProvider.now))))
        } else if let pausedRemaining {
            remainingSeconds = max(0, Int(ceil(pausedRemaining)))
        }
    }

    func checkForCompletion() {
        guard status == .running, let endDate, endDate.timeIntervalSince(dateProvider.now) <= 0 else { return }
        remainingSeconds = 0
        status = .complete
        self.endDate = nil
        onPhaseCompleted?()
        persist()
        scheduleAutoAdvanceIfNeeded()
        emitStateChange(.completed)
    }

    func syncIdleDuration(ifCurrentPhaseIs phase: Phase, seconds: Int) {
        guard status == .idle, self.phase == phase else { return }
        remainingSeconds = seconds
        pausedRemaining = TimeInterval(seconds)
    }

    private func transitionToNextPhase(status nextStatus: RunStatus) {
        let next = phase.next(sessionIndex: sessionIndex, sessionsPerCycle: sessionsPerCycle)
        phase = next.phase
        sessionIndex = next.sessionIndex
        let fullDuration = durationProvider.duration(for: phase)
        remainingSeconds = fullDuration
        pausedRemaining = nextStatus == .idle ? TimeInterval(fullDuration) : nil
        endDate = nextStatus == .running ? dateProvider.now.addingTimeInterval(TimeInterval(fullDuration)) : nil
        status = nextStatus
        persist()
    }

    private func emitStateChange(_ kind: TransitionKind) {
        onStateChange?(phase, sessionIndex, currentRenderState, kind)
    }

    var currentRenderState: RenderState {
        switch status {
        case .running:
            let phaseEnd = endDate!
            let phaseStart = phaseEnd.addingTimeInterval(-TimeInterval(durationProvider.duration(for: phase)))
            return .running(phaseStart: phaseStart, phaseEnd: phaseEnd)
        case .idle:
            return .idle(phaseDurationSeconds: durationProvider.duration(for: phase))
        case .paused:
            return .paused(
                remainingSeconds: Int(pausedRemaining ?? 0),
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
        persister.save(TimerSnapshot(phase: phase, status: status, sessionIndex: sessionIndex, endDate: endDate, pausedRemaining: pausedRemaining))
    }
}
