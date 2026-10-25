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
    var sessionsPerCycle: Int { durationProvider.sessionsPerCycle }
    // Stored so the macOS no-window timer loop triggers observation updates.
    private(set) var remainingSeconds: Int
    var autoStartNext = true
    var onPhaseCompleted: (() -> Void)?
    enum TransitionKind { case started, resumed, paused, completed, skipped, startedNext, reset, reconciled, reanchored }
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
            let fallbackDuration = durationProvider.duration(for: snapshot.phase)
            let timeRemaining: TimeInterval = snapshot.status == .paused
                ? (snapshot.pausedRemaining ?? 0)
                : max(0, (snapshot.endDate ?? .distantPast).timeIntervalSince(dateProvider.now))
            let phaseDuration = snapshot.phaseDuration ?? max(fallbackDuration, Int(timeRemaining.rounded(.up)))
            state = TimerRunState(
                status: snapshot.status,
                endDate: snapshot.endDate,
                pausedRemaining: snapshot.pausedRemaining,
                phaseDuration: phaseDuration
            )
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
        let phaseDuration = durationProvider.duration(for: phase)
        state = .running(phaseDuration: phaseDuration,
                         endDate: dateProvider.now.addingTimeInterval(TimeInterval(phaseDuration)))
        persist()
        emitStateChange(.started)
    }

    func resume() {
        guard case .paused(let phaseDuration, let remaining) = state else { return }
        state = .running(phaseDuration: phaseDuration,
                         endDate: dateProvider.now.addingTimeInterval(remaining))
        recomputeRemaining()
        persist()
        emitStateChange(.resumed)
    }

    func pause() {
        guard case .running(let phaseDuration, let endDate) = state else { return }
        state = .paused(phaseDuration: phaseDuration,
                        remaining: max(0, endDate.timeIntervalSince(dateProvider.now)))
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

    func restartCycle() {
        autoAdvanceTask?.cancel()
        phase = .focus
        sessionIndex = 1
        state = .idle
        remainingSeconds = durationProvider.duration(for: .focus)
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
        case .running(_, let endDate):
            remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(dateProvider.now))))
        case .paused(_, let remaining):
            remainingSeconds = max(0, Int(ceil(remaining)))
        case .idle, .complete:
            break
        }
    }

    func checkForCompletion() {
        let now = dateProvider.now
        guard case .running(_, let endDate) = state, endDate <= now else { return }

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
        var landedPhaseDuration = 0

        while true {
            guard shouldAutomaticallyAdvance(after: landedPhase) else { break }
            let next = landedPhase.next(sessionIndex: landedSessionIndex, sessionsPerCycle: sessionsPerCycle)
            let nextDuration = durationProvider.duration(for: next.phase)
            let nextBoundary = boundary.addingTimeInterval(TimeInterval(nextDuration))
            landedPhase = next.phase
            landedSessionIndex = next.sessionIndex
            boundary = nextBoundary
            landedPhaseDuration = nextDuration
            if nextBoundary > now {
                break
            }
        }

        phase = landedPhase
        sessionIndex = landedSessionIndex
        if autoStartNext, boundary > now {
            state = .running(phaseDuration: landedPhaseDuration, endDate: boundary)
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
        guard case .running(_, let firstBoundary) = state else { return [] }

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

    var currentPhaseDuration: Int {
        switch state {
        case .running(let phaseDuration, _), .paused(let phaseDuration, _): phaseDuration
        case .idle, .complete: durationProvider.duration(for: phase)
        }
    }

    func restartCurrentPhase() {
        guard status == .running || status == .paused else { return }
        autoAdvanceTask?.cancel()
        let phaseDuration = durationProvider.duration(for: phase)
        remainingSeconds = phaseDuration
        switch state {
        case .running:
            state = .running(phaseDuration: phaseDuration,
                             endDate: dateProvider.now.addingTimeInterval(TimeInterval(phaseDuration)))
        case .paused:
            state = .paused(phaseDuration: phaseDuration, remaining: TimeInterval(phaseDuration))
        case .idle, .complete:
            return
        }
        persist()
        emitStateChange(.reanchored)
    }

    func reanchorSchedule() {
        guard status == .running || status == .paused else { return }
        emitStateChange(.reanchored)
    }

    private func transitionToNextPhase(autoStart: Bool) {
        let next = phase.next(sessionIndex: sessionIndex, sessionsPerCycle: sessionsPerCycle)
        phase = next.phase
        sessionIndex = next.sessionIndex
        let fullDuration = durationProvider.duration(for: phase)
        remainingSeconds = fullDuration
        state = autoStart
            ? .running(phaseDuration: fullDuration,
                       endDate: dateProvider.now.addingTimeInterval(TimeInterval(fullDuration)))
            : .idle
        persist()
    }

    private func emitStateChange(_ kind: TransitionKind) {
        onStateChange?(phase, sessionIndex, currentRenderState, kind)
    }

    var currentRenderState: RenderState {
        switch state {
        case .running(let phaseDuration, let phaseEnd):
            let phaseStart = phaseEnd.addingTimeInterval(-TimeInterval(phaseDuration))
            return .running(phaseStart: phaseStart, phaseEnd: phaseEnd)
        case .idle:
            return .idle(phaseDurationSeconds: durationProvider.duration(for: phase))
        case .paused(let phaseDuration, let remaining):
            return .paused(
                remainingSeconds: Int(ceil(remaining)),
                phaseDurationSeconds: phaseDuration
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
        let (status, endDate, pausedRemaining, phaseDuration) = state.snapshotFields
        persister.save(TimerSnapshot(
            phase: phase,
            status: status,
            sessionIndex: sessionIndex,
            endDate: endDate,
            pausedRemaining: pausedRemaining,
            phaseDuration: phaseDuration
        ))
    }
}
