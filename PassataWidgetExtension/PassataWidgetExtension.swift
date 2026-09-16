import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PassataWidgetExtension: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PassataActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .environment(\.colorScheme, .dark)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandExpandedView(state: context.state)
                        .environment(\.colorScheme, .dark)
                }
            } compactLeading: {
                DynamicIslandCompactLeadingView(state: context.state)
                    .environment(\.colorScheme, .dark)
            } compactTrailing: {
                DynamicIslandCompactTrailingView(state: context.state)
                    .environment(\.colorScheme, .dark)
            } minimal: {
                ActivityProgressView(
                    render: context.state.render,
                    accent: PassataPalette.accent(for: context.state.phase)
                )
                .frame(width: 19, height: 19)
            }
        }
    }
}

#Preview("Minimal progress states") {
    let now = Date()
    let states = [
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .idle(phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .running(phaseStart: now.addingTimeInterval(-300), phaseEnd: now.addingTimeInterval(1200))),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .paused(remainingSeconds: 600, phaseDurationSeconds: 1500)),
        PassataActivityAttributes.ContentState(phase: .focus, sessionIndex: 1, sessionsPerCycle: 4, render: .complete)
    ]

    return HStack(spacing: 12) {
        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
            ActivityProgressView(
                render: state.render,
                accent: PassataPalette.accent(for: state.phase)
            )
            .frame(width: 19, height: 19)
            .padding(8)
            .background(.black)
        }
    }
}
