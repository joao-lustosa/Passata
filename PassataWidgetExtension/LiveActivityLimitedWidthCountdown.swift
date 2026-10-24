import SwiftUI

struct LiveActivityLimitedWidthCountdown: View {
    let render: RenderState

    @ViewBuilder
    var body: some View {
        switch render {
        case let .running(phaseStart, phaseEnd):
            Text(.currentDate, format: CompactCountdownFormat.timerStyle(countingDownIn: phaseStart..<phaseEnd))
        case .idle(let durationSeconds):
            Text(minutesLabel(for: durationSeconds))
        case .paused(let remainingSeconds, _):
            Text(minutesLabel(for: remainingSeconds))
        case .complete:
            Text("0")
        }
    }

    private func minutesLabel(for seconds: Int) -> String {
        let nonnegativeSeconds = max(0, seconds)
        let wholeMinutes = nonnegativeSeconds / 60
        let hasRemainder = nonnegativeSeconds % 60 == 0 ? 0 : 1
        return String(wholeMinutes + hasRemainder)
    }
}
