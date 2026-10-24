import SwiftUI

struct LiveActivityLimitedWidthCountdown: View {
    let render: RenderState

    @ViewBuilder
    var body: some View {
        if case let .running(phaseStart, phaseEnd) = render {
            Text(.currentDate, format: CompactCountdownFormat.timerStyle(countingDownIn: phaseStart..<phaseEnd))
        } else if let label = CompactCountdownFormat.limitedWidthStaticLabel(for: render) {
            Text(label)
        }
    }
}
