import ActivityKit
import Foundation

#if DEBUG
import SwiftUI
#endif

protocol LiveActivityPublishing {
    nonisolated func hasActiveActivity() async -> Bool
    nonisolated func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws
    nonisolated func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async
    nonisolated func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async
}

extension LiveActivityPublishing {
    nonisolated func endImmediately(_ content: PassataActivityAttributes.ContentState?) async {
        await end(content, dismissalPolicy: .immediate)
    }
}

// Activity's async update/end are treated as @concurrent on import and Activity itself isn't
// Sendable -- an SDK annotation gap, not something we control. Overlapping calls from
// LiveActivityController's two task origins are possible and already accepted as benign
// (see PassataApp's launch reconciliation); this asserts ActivityKit's own API tolerates
// concurrent invocation by design, not that we've serialized access to it. This is an
// inference about the framework's contract. Revisit if ActivityKit ships the annotation.
extension Activity: @retroactive @unchecked Sendable {}

nonisolated final class SystemLiveActivityPublisher: LiveActivityPublishing {
    private let lock = NSLock()
    private var currentActivity: Activity<PassataActivityAttributes>?

    nonisolated init() {}

    func hasActiveActivity() async -> Bool {
        guard let found = Activity<PassataActivityAttributes>.activities.first else { return false }
        lock.withLock { currentActivity = found }
        return true
    }

    func request(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) throws {
        let activity = try Activity<PassataActivityAttributes>.request(
            attributes: PassataActivityAttributes(),
            content: ActivityContent(state: content, staleDate: staleDate)
        )
        lock.withLock { currentActivity = activity }
    }

    func update(_ content: PassataActivityAttributes.ContentState, staleDate: Date?) async {
        let activity = lock.withLock { currentActivity }
        await activity?.update(ActivityContent(state: content, staleDate: staleDate))
    }

    func end(_ content: PassataActivityAttributes.ContentState?, dismissalPolicy: ActivityUIDismissalPolicy) async {
        let activity = lock.withLock { currentActivity }
        await activity?.end(
            content.map { ActivityContent(state: $0, staleDate: nil) },
            dismissalPolicy: dismissalPolicy
        )
        lock.withLock { currentActivity = nil }
    }
}

#if DEBUG
// Throwaway issue #7 probe; this source already has macOS/visionOS exclusions.
enum ScheduledLiveActivitySpikeConfiguration {
    static var isEnabled: Bool { true }
}

@MainActor @Observable
final class ScheduledLiveActivitySpike {
    var log = ""
    var busy = false
    private var retained: [Activity<PassataActivityAttributes>] = []
    private let evidenceURL = URL.documentsDirectory.appending(path: "scheduled-activity-spike.log")

    func record(_ message: String) {
        let line = "\(Date().ISO8601Format()) \(message)"
        log += line + "\n"
        print("ISSUE7 \(line)")
        do { try log.write(to: evidenceURL, atomically: true, encoding: .utf8) }
        catch { print("ISSUE7 evidence write failed: \(error)") }
    }

    func snapshot() {
        record("snapshot enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
        for activity in Activity<PassataActivityAttributes>.activities {
            record("enumerated \(activity.id) state=\(activity.activityState) phase=\(activity.content.state.phase) score=\(activity.content.relevanceScore)")
        }
        for activity in retained { record("retained \(activity.id) state=\(activity.activityState)") }
    }

    func clear() async {
        for activity in Activity<PassataActivityAttributes>.activities {
            record("clear \(activity.id) before=\(activity.activityState)")
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        retained = []
        snapshot()
    }

    private func content(_ phase: Phase, start: Date, end: Date, score: Double) -> ActivityContent<PassataActivityAttributes.ContentState> {
        .init(state: .init(phase: phase, sessionIndex: 1, sessionsPerCycle: 4,
                           render: .running(phaseStart: start, phaseEnd: end)),
              staleDate: end, relevanceScore: score)
    }

    private func schedule(start: Date, score: Double) throws -> Activity<PassataActivityAttributes> {
        try Activity.request(
            attributes: PassataActivityAttributes(),
            content: content(.shortBreak, start: start, end: start.addingTimeInterval(300), score: score),
            pushType: nil, style: .standard,
            alertConfiguration: .init(title: "Passata spike", body: "Next phase starts now", sound: .default),
            start: start
        )
    }

    func cancellationGate() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        await clear()
        record("GATE1 begin: three pending cancellation trials")
        do {
            for delay in [0, 2, 10] {
                let start = Date().addingTimeInterval(12)
                let activity = try schedule(start: start, score: 100)
                retained.append(activity)
                record("GATE1 requested \(activity.id) state=\(activity.activityState) start=\(start.ISO8601Format()) cancelDelay=\(delay)")
                try await Task.sleep(for: .seconds(delay))
                guard activity.activityState == .pending else {
                    record("GATE1 NO-GO: expected pending before end, got \(activity.activityState)")
                    return
                }
                await activity.end(nil, dismissalPolicy: .immediate)
                record("GATE1 end returned \(activity.id) state=\(activity.activityState)")
                try await Task.sleep(for: .seconds(max(0, start.timeIntervalSinceNow) + 2))
                let present = Activity<PassataActivityAttributes>.activities.contains { $0.id == activity.id }
                record("GATE1 after deadline \(activity.id) state=\(activity.activityState) enumerated=\(present)")
                guard !present, activity.activityState == .dismissed || activity.activityState == .ended else {
                    record("GATE1 NO-GO: pending activity survived cancellation")
                    return
                }
            }
            record("GATE1 GO: all three cancelled pending activities stayed absent after start")
        } catch { record("GATE1 ERROR \(String(reflecting: error))") }
    }

    func pair() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        await clear()
        do {
            let now = Date()
            let boundary = now.addingTimeInterval(45)
            let first = try Activity<PassataActivityAttributes>.request(
                attributes: PassataActivityAttributes(),
                content: content(.focus, start: now, end: boundary, score: 10), pushType: nil)
            retained.append(first)
            let second = try schedule(start: boundary, score: 100)
            retained.append(second)
            record("PAIR A=\(first.id) focus score10 end=\(boundary.ISO8601Format())")
            record("PAIR B=\(second.id) break score100 start=\(boundary.ISO8601Format()) state=\(second.activityState)")
            snapshot()
        } catch { record("PAIR ERROR \(String(reflecting: error))") }
    }

    func promotePrevious() async {
        guard let first = retained.first ?? Activity<PassataActivityAttributes>.activities.first(where: {
            $0.content.state.phase == .focus
        }) else { return }
        let old = first.content
        await first.update(.init(state: old.state, staleDate: old.staleDate, relevanceScore: 200))
        record("PROMOTE A score200 (old phase)")
        snapshot()
    }
}

struct ScheduledLiveActivitySpikeView: View {
    @State private var probe = ScheduledLiveActivitySpike()

    var body: some View {
        NavigationStack {
            Form {
                Section("Blocking cancellation gate") {
                    Button("Run cancellation gate (42 seconds)") {
                        Task { await probe.cancellationGate() }
                    }.disabled(probe.busy)
                }
                Section("Only after gate passes") {
                    Button("Start A and schedule B in 45 seconds") { Task { await probe.pair() } }
                        .disabled(probe.busy)
                    Button("Promote previous A to score 200") { Task { await probe.promotePrevious() } }
                    Button("Snapshot activities") { probe.snapshot() }
                    Button("End all spike activities") { Task { await probe.clear() } }
                }
                Section("Evidence") {
                    Text(probe.log.isEmpty ? "Ready — Live Activities permission may appear." : probe.log)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                }
            }.navigationTitle("Scheduled activity spike")
                .task {
                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains("-SpikeCancellationGate") {
                        await probe.cancellationGate()
                    } else if arguments.contains("-SpikePair") {
                        await probe.pair()
                    } else if arguments.contains("-SpikeSnapshot") {
                        probe.snapshot()
                    } else if arguments.contains("-SpikePromote") {
                        await probe.promotePrevious()
                    } else if arguments.contains("-SpikeClear") {
                        await probe.clear()
                    } else {
                        probe.snapshot()
                    }
                }
        }
    }
}
#endif
