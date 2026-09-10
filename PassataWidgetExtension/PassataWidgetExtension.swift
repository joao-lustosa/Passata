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
                DynamicIslandExpandedRegion(.center) { EmptyView() }
            } compactLeading: {
                DynamicIslandCompactLeadingView(state: context.state)
                    .environment(\.colorScheme, .dark)
            } compactTrailing: {
                DynamicIslandCompactTrailingView(state: context.state)
                    .environment(\.colorScheme, .dark)
            } minimal: {
                EmptyView()
            }
        }
    }
}
