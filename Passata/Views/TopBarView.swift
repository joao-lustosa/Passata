import SwiftUI

struct TopBarView: View {
    let engine: TimerEngine
    let onSettingsTapped: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sessionDots: some View {
        SessionDotsView(
            phase: engine.phase,
            sessionIndex: engine.sessionIndex,
            sessionsPerCycle: engine.sessionsPerCycle
        )
    }

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
            sessionDots
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                settingsButton
            }
        }
        .padding(.horizontal, 20)
        #else
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    sessionDots
                        .frame(maxWidth: .infinity)

                    HStack {
                        Spacer(minLength: 0)
                        settingsButton
                    }
                }
                .padding(.horizontal, 20)
            } else {
                HStack {
                    sessionDots
                    Spacer()
                    settingsButton
                }
                .padding(.horizontal, 20)
            }
        }
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
