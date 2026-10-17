import SwiftUI

struct LiveActivitySessionDotsView: View {
    let phase: Phase
    let sessionIndex: Int
    let sessionsPerCycle: Int
    let accent: Color

    private var filledCount: Int {
        phase == .focus ? sessionIndex - 1 : sessionIndex
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...sessionsPerCycle, id: \.self) { dotNumber in
                let filled = dotNumber <= filledCount
                let current = phase == .focus && dotNumber == sessionIndex && !filled
                Circle()
                    .fill(filled ? Color("PassataFocus") : Color.clear)
                    .overlay {
                        if current {
                            Circle().stroke(accent, lineWidth: 1.5)
                        } else if !filled {
                            Circle().stroke(Color.white.opacity(0.42), lineWidth: 1.5)
                        }
                    }
                    .frame(width: current ? 7.5 : 6, height: current ? 7.5 : 6)
            }
        }
    }
}
