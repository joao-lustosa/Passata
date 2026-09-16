import SwiftUI

struct TopBarView: View {
    let engine: TimerEngine
    let onSettingsTapped: () -> Void

    private var settingsButton: some View {
        Button(action: onSettingsTapped) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color("PassataInk2"))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .circle)
        .accessibilityLabel("Settings")
    }

    var body: some View {
        #if os(macOS)
        ZStack {
            SessionDotsView(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle
            )
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                settingsButton
            }
        }
        .padding(.horizontal, 20)
        #else
        HStack {
            SessionDotsView(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle
            )

            Spacer()
            settingsButton
        }
        .padding(.horizontal, 20)
        #endif
    }
}

struct PassataMacHoverFeedback: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onHover { isHovered = $0 }
            .brightness(isHovered ? 0.08 : 0)
        #else
        content
        #endif
    }
}

extension View {
    func passataMacHoverFeedback() -> some View {
        modifier(PassataMacHoverFeedback())
    }
}
