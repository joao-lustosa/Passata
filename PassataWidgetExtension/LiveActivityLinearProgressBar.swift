import SwiftUI

struct LiveActivityLinearProgressBar: View {
    let render: RenderState
    let accent: Color
    let track: Color

    @ViewBuilder
    var body: some View {
        switch render {
        case let .running(phaseStart, phaseEnd):
            ProgressView(timerInterval: phaseStart...phaseEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
                .tint(accent)
                .progressViewStyle(.linear)
        default:
            GeometryReader { proxy in
                Capsule()
                    .fill(track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * CGFloat(render.staticProgress))
                    }
            }
            .frame(height: 6)
        }
    }
}
