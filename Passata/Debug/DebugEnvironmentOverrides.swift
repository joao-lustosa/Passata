import SwiftUI

private struct PassataDebugReduceTransparencyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var passataDebugReduceTransparency: Bool {
        get { self[PassataDebugReduceTransparencyKey.self] }
        set { self[PassataDebugReduceTransparencyKey.self] = newValue }
    }
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
