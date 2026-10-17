import SwiftUI

/// A simplified, single-color silhouette derived from the app icon's tomato body and stem
/// (see design/AppIconRenderer/IconRenderer.swift for the full detailed icon this simplifies).
/// Intentionally drops the leaves and clock-dial marks -- illegible at the ~14pt sizes this
/// renders at in Live Activity/Lock Screen contexts. Designed as a Shape (not an Image asset)
/// so it adopts ambient .foregroundStyle(...) the same way the SF Symbol placeholder it replaces did.
struct PassataGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()

        let stemRect = CGRect(x: 11 * scale, y: 1.5 * scale, width: 2 * scale, height: 5 * scale)
        path.addRoundedRect(in: stemRect, cornerSize: CGSize(width: scale, height: scale))

        let bodyRect = CGRect(x: 4 * scale, y: 7 * scale, width: 16 * scale, height: 16 * scale)
        path.addEllipse(in: bodyRect)

        return path
    }
}
