import SwiftUI

@available(iOS 27.0, *)
struct DynamicIslandMinimalView: View {
    let state: PassataActivityAttributes.ContentState

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    var body: some View {
        ActivityProgressView(render: state.render, accent: accent)
        .frame(width: 19, height: 19)
    }
}

struct DynamicIslandMinimalFallbackView: View {
    let state: PassataActivityAttributes.ContentState

    var body: some View {
        ActivityProgressView(
            render: state.render,
            accent: PassataPalette.accent(for: state.phase)
        )
        .frame(width: 19, height: 19)
    }
}

struct DynamicIslandMinimalContent: View {
    let state: PassataActivityAttributes.ContentState

    @ViewBuilder
    var body: some View {
        if #available(iOS 27.0, *) {
            DynamicIslandMinimalView(state: state)
        } else {
            DynamicIslandMinimalFallbackView(state: state)
        }
    }
}
