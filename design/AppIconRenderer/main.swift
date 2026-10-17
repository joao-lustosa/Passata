import AppKit
import Darwin
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@main
struct IconRendererMain {
    static func main() throws {
        setvbuf(stdout, nil, _IONBF, 0)
        let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "design/AppIconRenderer")
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            print("Directory creation failed at \(outputDirectory.path): \(error)")
            throw error
        }
        let renders: [(String, Color)] = [
            ("PassataIcon-light.png", Color(red: 0xFB / 255, green: 0xF4 / 255, blue: 0xED / 255)),
            ("PassataIcon-dark.png", Color(red: 0x12 / 255, green: 0x0C / 255, blue: 0x07 / 255))
        ]
        for (name, background) in renders {
            let renderer = ImageRenderer(content: PassataIconArtwork(background: background).frame(width: 1024, height: 1024))
            renderer.scale = 1
            guard let nsImage = renderer.nsImage,
                  let source = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                print("ImageRenderer did not produce a source image")
                throw CocoaError(.fileWriteUnknown)
            }
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil,
                    width: 1024,
                    height: 1024,
                    bitsPerComponent: 8,
                    bytesPerRow: 1024 * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                  ) else {
                print("Could not create RGB CGContext")
                throw CocoaError(.fileWriteUnknown)
            }
            context.draw(source, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
            guard let flattened = context.makeImage() else {
                print("RGB context did not produce a CGImage")
                throw CocoaError(.fileWriteUnknown)
            }
            let outputURL = outputDirectory.appendingPathComponent(name)
            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else {
                print("Could not create PNG destination for \(outputURL.path)")
                throw CocoaError(.fileWriteUnknown)
            }
            CGImageDestinationAddImage(destination, flattened, nil)
            guard CGImageDestinationFinalize(destination) else {
                print("PNG finalize failed at \(outputURL.path)")
                throw CocoaError(.fileWriteUnknown)
            }
        }
    }
}
