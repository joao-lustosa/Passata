import SwiftUI

struct SessionDotsView: View {
    let phase: Phase
    let sessionIndex: Int
    let sessionsPerCycle: Int

    private var filledCount: Int {
        phase == .focus ? sessionIndex - 1 : sessionIndex
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...sessionsPerCycle, id: \.self) { dotNumber in
                let isFilled = dotNumber <= filledCount
                let isCurrent = phase == .focus && dotNumber == sessionIndex && !isFilled

                Circle()
                    .fill(isFilled ? PassataPalette.accent(for: phase) : .clear)
                    .overlay {
                        if !isFilled {
                            Circle()
                                .stroke(
                                    isCurrent ? PassataPalette.accent(for: phase) : Color("PassataInk3"),
                                    lineWidth: 2
                                )
                        }
                    }
                    .frame(width: isCurrent ? 9 : 7, height: isCurrent ? 9 : 7)
                    .animation(.easeInOut(duration: 0.15), value: phase)
                    .animation(.easeInOut(duration: 0.15), value: sessionIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session \(sessionIndex) of \(sessionsPerCycle)")
    }
}
