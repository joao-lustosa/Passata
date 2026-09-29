import SwiftUI

extension EnvironmentValues {
    @Entry var passataDebugReduceTransparency: Bool = false
}

#if DEBUG
struct DebugEnvironmentOverrides: ViewModifier {
    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("-PassataForceReduceTransparency") {
            content.environment(\.passataDebugReduceTransparency, true)
        } else {
            content
        }
    }
}
#else
struct DebugEnvironmentOverrides: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#endif
