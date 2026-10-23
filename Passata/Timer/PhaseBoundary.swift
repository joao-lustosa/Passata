import Foundation

nonisolated struct PhaseBoundary: Equatable, Sendable {
    let phase: Phase
    let sessionIndex: Int
    let phaseEnd: Date
}
