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

    private var autoAdvanceTask: Task<Void, Never>?
    private let durationProvider: any DurationProviding
    private let dateProvider: any DateProviding
    private let persister: any TimerStatePersisting

    init(
        durationProvider: any DurationProviding,
        dateProvider: any DateProviding = SystemDateProvider(),
        persister: any TimerStatePersisting = NoOpTimerStateStore()
    ) {
        self.durationProvider = durationProvider
        self.dateProvider = dateProvider
        self.persister = persister

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
    }

    func resume() {
        guard status == .paused else { return }
        let remaining = pausedRemaining ?? 0
        endDate = dateProvider.now.addingTimeInterval(remaining)
        pausedRemaining = nil
        status = .running
        recomputeRemaining()
        persist()
    }

    func pause() {
        guard status == .running else { return }
        pausedRemaining = max(0, endDate?.timeIntervalSince(dateProvider.now) ?? 0)
        endDate = nil
        status = .paused
        recomputeRemaining()
        persist()
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
    }

    func onSkip() {
        autoAdvanceTask?.cancel()
        transitionToNextPhase(status: .idle)
    }

    func onStartNext() {
        autoAdvanceTask?.cancel()
        transitionToNextPhase(status: .running)
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
