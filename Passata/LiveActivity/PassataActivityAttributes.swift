import ActivityKit

struct PassataActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: Phase
        var sessionIndex: Int
        var render: RenderState
    }
}
