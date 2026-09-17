import SwiftUI

struct LiveActivityTimeText: View {
    let render: RenderState

    @ViewBuilder
    var body: some View {
        switch render {
        case let .running(phaseStart, phaseEnd):
            Text(timerInterval: phaseStart...phaseEnd, countsDown: true)
        case let .idle(seconds), let .paused(seconds, _):
            Text(seconds.asClockString)
        case .complete:
            Text("00:00")
        }
    }
}
