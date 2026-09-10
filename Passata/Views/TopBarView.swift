import SwiftUI

struct TopBarView: View {
    let engine: TimerEngine
    let onSettingsTapped: () -> Void

    var body: some View {
        HStack {
            SessionDotsView(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle
            )

            Spacer()

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
        .padding(.horizontal, 20)
    }
}
