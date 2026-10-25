#if os(iOS)
import BackgroundTasks
import Foundation

@MainActor
enum BackgroundRefreshScheduler {
    nonisolated static let identifier = "app.passata.Passata.refresh"

    static func schedule(for engine: TimerEngine) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let earliestBeginDate: Date
        switch engine.status {
        case .running:
            guard case .running(_, let phaseEnd) = engine.currentRenderState else { return }
            earliestBeginDate = phaseEnd
        case .complete where engine.autoStartNext && engine.phase != .longBreak:
            earliestBeginDate = Date().addingTimeInterval(3)
        case .idle, .paused, .complete:
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background refresh is best effort; end-date reconciliation remains authoritative.
        }
    }

    static func reconcile(_ engine: TimerEngine) {
        engine.recomputeRemaining()
        engine.checkForCompletion()
        schedule(for: engine)
    }
}
#endif
