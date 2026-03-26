import AppKit
import Foundation

private struct DMGBackgroundRenderer {
    static func render(size: CGSize, outputURL: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let rep else { return }
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let rect = CGRect(origin: .zero, size: size)
        let background = NSBezierPath(rect: rect)
        let gradient = NSGradient(colors: [
            NSColor(calibratedWhite: 0.08, alpha: 1),
            NSColor(calibratedWhite: 0.12, alpha: 1),
            NSColor(calibratedWhite: 0.16, alpha: 1)
        ])
        gradient?.draw(in: background, angle: -90)

        let glow = NSBezierPath(roundedRect: rect.insetBy(dx: 18, dy: 18), xRadius: 28, yRadius: 28)
        NSColor(calibratedRed: 0.2, green: 0.9, blue: 1, alpha: 0.08).setStroke()
        glow.lineWidth = 2
        glow.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.9),
            .paragraphStyle: paragraph
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.55),
            .paragraphStyle: paragraph
        ]

        let title = "Drag NewNet to Applications"
        let subtitle = "Install by dropping the app into the Applications folder"

        let titleRect = CGRect(x: 0, y: size.height * 0.62, width: size.width, height: 40)
        let subtitleRect = CGRect(x: 0, y: size.height * 0.56, width: size.width, height: 24)

        title.draw(in: titleRect, withAttributes: titleAttributes)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)

        NSGraphicsContext.restoreGraphicsState()

        if let data = rep.representation(using: .png, properties: [:]) {
            try data.write(to: outputURL)
        }
    }
}

let outputPath = CommandLine.arguments.dropFirst().first ?? "dmg_background.png"
let outputURL = URL(fileURLWithPath: outputPath)
try DMGBackgroundRenderer.render(size: CGSize(width: 660, height: 400), outputURL: outputURL)
print("Generated DMG background at \(outputURL.path)")
