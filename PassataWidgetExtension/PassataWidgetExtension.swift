import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PassataWidgetExtension: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PassataActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .environment(\.colorScheme, .dark)
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { EmptyView() }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }
}
