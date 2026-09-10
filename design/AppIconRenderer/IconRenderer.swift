import SwiftUI

struct PassataIconArtwork: View {
    let background: Color

    private let stem = Color(red: 0x2F / 255, green: 0x7F / 255, blue: 0x3C / 255)
    private let leaves = Color(red: 0x3F / 255, green: 0x9B / 255, blue: 0x4C / 255)
    private let bodyColor = Color(red: 0xDA / 255, green: 0x3F / 255, blue: 0x26 / 255)
    private let shadow = Color(red: 0x8E / 255, green: 0x1F / 255, blue: 0x10 / 255)
    private let iconCut = Color(red: 0.9874, green: 0.9663, blue: 0.9155)

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
                let scale = min(size.width, size.height) / 48
                context.scaleBy(x: scale, y: scale)

                func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat, fill: Color, opacity: Double = 1) {
                    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .path(in: CGRect(x: x, y: y, width: width, height: height))
                    context.fill(shape, with: .color(fill.opacity(opacity)))
                }
                func ellipse(_ center: CGPoint, _ radius: CGSize, fill: Color, opacity: Double = 1, angle: Angle = .zero) {
                    var path = Path(ellipseIn: CGRect(x: center.x - radius.width, y: center.y - radius.height, width: radius.width * 2, height: radius.height * 2))
                    if angle != .zero {
                        let transform = CGAffineTransform(translationX: center.x, y: center.y)
                            .rotated(by: angle.radians)
                            .translatedBy(x: -center.x, y: -center.y)
                        path = path.applying(transform)
                    }
                    context.fill(path, with: .color(fill.opacity(opacity)))
                }

                rect(23.15, 5.5, 1.8, 5, radius: 0.9, fill: stem)
                ellipse(CGPoint(x: 24, y: 11.1), CGSize(width: 5.8, height: 1.9), fill: leaves)
                ellipse(CGPoint(x: 24, y: 11.1), CGSize(width: 5.8, height: 1.9), fill: leaves, angle: .degrees(56))
                ellipse(CGPoint(x: 24, y: 11.1), CGSize(width: 5.8, height: 1.9), fill: leaves, angle: .degrees(-56))

                ellipse(CGPoint(x: 24, y: 26.5), CGSize(width: 16.8, height: 16.8), fill: bodyColor)
                ellipse(CGPoint(x: 28.6, y: 34.5), CGSize(width: 12.2, height: 7.6), fill: shadow, opacity: 0.2)
                ellipse(CGPoint(x: 17.9, y: 19.9), CGSize(width: 7.6, height: 5.2), fill: .white, opacity: 0.17, angle: .degrees(-32))

                rect(23.2, 12.1, 1.6, 3.4, radius: 0.8, fill: iconCut, opacity: 0.9)
                rect(23.2, 37.5, 1.6, 3.4, radius: 0.8, fill: iconCut, opacity: 0.9)
                rect(35, 25.7, 3.4, 1.6, radius: 0.8, fill: iconCut, opacity: 0.9)
                rect(9.6, 25.7, 3.4, 1.6, radius: 0.8, fill: iconCut, opacity: 0.9)

                let ring = Path(ellipseIn: CGRect(x: 11.4, y: 13.9, width: 25.2, height: 25.2))
                context.stroke(ring, with: .color(iconCut.opacity(0.22)), lineWidth: 1.1)

                var highlight = Path()
                highlight.move(to: CGPoint(x: 24, y: 26.5))
                highlight.addLine(to: CGPoint(x: 31.5, y: 20.3))
                context.stroke(highlight, with: .color(iconCut), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                ellipse(CGPoint(x: 24, y: 26.5), CGSize(width: 1.9, height: 1.9), fill: iconCut)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .background(background)
        .clipped()
    }
}
