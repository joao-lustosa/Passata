import SwiftUI

struct DynamicIslandMinimalView: View {
    let state: PassataActivityAttributes.ContentState

    private var accent: Color { PassataPalette.accent(for: state.phase) }

    var body: some View {
        ActivityProgressView(render: state.render, accent: accent)
            .frame(width: 19, height: 19)
    }
}
