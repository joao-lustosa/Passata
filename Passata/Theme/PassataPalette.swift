import SwiftUI

/// Resolves the semantic timer accents from any phase whose raw values match the domain phase names.
/// The generic constraint keeps this theme-only branch independent from the future `Phase` domain type.
enum PassataPalette {
    static func accent<Phase>(for phase: Phase) -> Color where Phase: RawRepresentable, Phase.RawValue == String {
        return switch phase.rawValue {
        case "focus": Color("PassataFocus")
        case "shortBreak": Color("PassataShortBreak")
        case "longBreak": Color("PassataLongBreak")
        default: fatalError("Unexpected phase raw value: \(phase.rawValue)")
        }
    }

    static func accentDeep<Phase>(for phase: Phase) -> Color where Phase: RawRepresentable, Phase.RawValue == String {
        return switch phase.rawValue {
        case "focus": Color("PassataFocusDeep")
        case "shortBreak": Color("PassataShortBreakDeep")
        case "longBreak": Color("PassataLongBreakDeep")
        default: fatalError("Unexpected phase raw value: \(phase.rawValue)")
        }
    }

    static func settingsGroupBackground(colorScheme: ColorScheme, reduceTransparency: Bool) -> Color {
        switch (colorScheme, reduceTransparency) {
        case (.dark, _): Color("PassataGroupElevated")
        case (.light, true): Color("PassataBackground")
        case (.light, false): Color("PassataGroupNonRT")
        @unknown default: Color("PassataGroupNonRT")
        }
    }

    /// The caller uses this only when Reduce Transparency is enabled.
    static func overlayCardRTBackground() -> Color {
        Color("PassataOverlayCardRT")
    }

    /// The caller uses this only when Reduce Transparency is enabled.
    static func sheetRTBackground() -> Color {
        Color("PassataSheetRT")
    }
}
