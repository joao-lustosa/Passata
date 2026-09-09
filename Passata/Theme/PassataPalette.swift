import SwiftUI

enum PassataPalette {
    static func accent(for phase: Phase) -> Color {
        switch phase {
        case .focus: Color("PassataFocus")
        case .shortBreak: Color("PassataShortBreak")
        case .longBreak: Color("PassataLongBreak")
        }
    }

    static func accentDeep(for phase: Phase) -> Color {
        switch phase {
        case .focus: Color("PassataFocusDeep")
        case .shortBreak: Color("PassataShortBreakDeep")
        case .longBreak: Color("PassataLongBreakDeep")
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
