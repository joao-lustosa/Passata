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
                DeterminateCircularProgressView(
                    progress: context.state.render.staticProgress,
                    accent: PassataPalette.accent(for: context.state.phase)
                )
                .frame(width: 19, height: 19)
            }
        }
    }
}
