nonisolated struct StateChangeEvent: Sendable {
    let phase: Phase
    let sessionIndex: Int
    let render: RenderState
    let kind: TimerEngine.TransitionKind
}
