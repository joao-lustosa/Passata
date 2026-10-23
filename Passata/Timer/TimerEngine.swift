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
    enum TransitionKind { case started, resumed, paused, completed, skipped, startedNext, reset, reconciled }
    var onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TransitionKind) -> Void)?

    @ObservationIgnored
    private var autoAdvanceTask: Task<Void, Never>?
    private let durationProvider: any DurationProviding
    private let dateProvider: any DateProviding
    private let persister: any TimerStatePersisting
    private let autoAdvanceDelay: any AutoAdvanceDelaying
    private let completionLatenessTolerance: TimeInterval = 2

    init(
        durationProvider: any DurationProviding,
        dateProvider: any DateProviding = SystemDateProvider(),
        persister: any TimerStatePersisting = UserDefaultsTimerStateStore(),
        autoAdvanceDelay: any AutoAdvanceDelaying = SystemAutoAdvanceDelay(),
        autoStartNext: Bool = true,
        onPhaseCompleted: (() -> Void)? = nil,
        onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TransitionKind) -> Void)? = nil
    ) {
        self.durationProvider = durationProvider
        self.dateProvider = dateProvider
        self.persister = persister
        self.autoAdvanceDelay = autoAdvanceDelay
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
        let now = dateProvider.now
        guard case .running(let endDate) = state, endDate <= now else { return }

        guard now.timeIntervalSince(endDate) > completionLatenessTolerance else {
            completeLivePhase()
            return
        }

        reconcileMissedPhases(from: endDate, through: now)
    }

    private func completeLivePhase() {
        remainingSeconds = 0
        state = .complete
        onPhaseCompleted?()
        persist()
        scheduleAutoAdvanceIfNeeded()
        emitStateChange(.completed)
    }

    private func reconcileMissedPhases(from firstBoundary: Date, through now: Date) {
        var landedPhase = phase
        var landedSessionIndex = sessionIndex
        var boundary = firstBoundary

        while true {
            guard shouldAutomaticallyAdvance(after: landedPhase) else { break }
            let next = landedPhase.next(sessionIndex: landedSessionIndex, sessionsPerCycle: sessionsPerCycle)
            let nextBoundary = boundary.addingTimeInterval(TimeInterval(durationProvider.duration(for: next.phase)))
            landedPhase = next.phase
            landedSessionIndex = next.sessionIndex
            boundary = nextBoundary
            if nextBoundary > now {
                break
            }
        }

        phase = landedPhase
        sessionIndex = landedSessionIndex
        if autoStartNext, boundary > now {
            state = .running(endDate: boundary)
            remainingSeconds = max(0, Int(ceil(boundary.timeIntervalSince(now))))
        } else {
            state = .complete
            remainingSeconds = 0
        }
        #if os(macOS)
        onPhaseCompleted?()
        #endif
        persist()
        emitStateChange(.reconciled)
    }

    var upcomingBoundaries: [PhaseBoundary] {
        guard case .running(let firstBoundary) = state else { return [] }

        var boundaries: [PhaseBoundary] = []
        var nextPhase = phase
        var nextSessionIndex = sessionIndex
        var boundary = firstBoundary

        while boundaries.count < 16 {
            boundaries.append(PhaseBoundary(phase: nextPhase, sessionIndex: nextSessionIndex, phaseEnd: boundary))
            guard shouldAutomaticallyAdvance(after: nextPhase) else { break }
            let next = nextPhase.next(sessionIndex: nextSessionIndex, sessionsPerCycle: sessionsPerCycle)
            boundary = boundary.addingTimeInterval(TimeInterval(durationProvider.duration(for: next.phase)))
            nextPhase = next.phase
            nextSessionIndex = next.sessionIndex
        }

        return boundaries
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
        guard shouldAutomaticallyAdvance(after: phase) else { return }
        autoAdvanceTask?.cancel()
        let delay = autoAdvanceDelay
        autoAdvanceTask = Task { [weak self, delay] in
            try? await delay.wait()
            guard !Task.isCancelled, let self, self.status == .complete else { return }
            self.onStartNext()
        }
    }

    private func shouldAutomaticallyAdvance(after phase: Phase) -> Bool {
        autoStartNext && phase != .longBreak
    }

    private func persist() {
        let (status, endDate, pausedRemaining) = state.snapshotFields
        persister.save(TimerSnapshot(phase: phase, status: status, sessionIndex: sessionIndex, endDate: endDate, pausedRemaining: pausedRemaining))
    }
}
