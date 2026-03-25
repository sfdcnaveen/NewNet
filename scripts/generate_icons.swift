import AppKit
import Foundation

private struct IconRenderer {
    static func render(size: Int, outputURL: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
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

        let cgContext = context?.cgContext
        cgContext?.setShouldAntialias(true)
        cgContext?.setAllowsAntialiasing(true)

        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let backgroundRect = rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04)
        let cornerRadius = CGFloat(size) * 0.22
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)

        let gradient = NSGradient(
            colors: [
                NSColor(calibratedWhite: 0.08, alpha: 1),
                NSColor(calibratedWhite: 0.14, alpha: 1),
                NSColor(calibratedWhite: 0.18, alpha: 1)
            ]
        )
        gradient?.draw(in: backgroundPath, angle: -90)

        NSColor(calibratedWhite: 1, alpha: 0.1).setStroke()
        backgroundPath.lineWidth = CGFloat(size) * 0.01
        backgroundPath.stroke()

        let gridRect = backgroundRect.insetBy(dx: CGFloat(size) * 0.09, dy: CGFloat(size) * 0.09)
        let gridPath = NSBezierPath()
        let steps = 8
        for index in 1..<steps {
            let t = CGFloat(index) / CGFloat(steps)
            let x = gridRect.minX + gridRect.width * t
            gridPath.move(to: CGPoint(x: x, y: gridRect.minY))
            gridPath.line(to: CGPoint(x: x, y: gridRect.maxY))

            let y = gridRect.minY + gridRect.height * t
            gridPath.move(to: CGPoint(x: gridRect.minX, y: y))
            gridPath.line(to: CGPoint(x: gridRect.maxX, y: y))
        }
        NSColor(calibratedRed: 0.35, green: 0.95, blue: 1, alpha: 0.08).setStroke()
        gridPath.lineWidth = CGFloat(size) * 0.004
        gridPath.stroke()

        let wavePath = NSBezierPath()
        let midY = backgroundRect.midY
        let minX = backgroundRect.minX + CGFloat(size) * 0.12
        let maxX = backgroundRect.maxX - CGFloat(size) * 0.12
        let width = maxX - minX
        let spikeHeight = CGFloat(size) * 0.23
        let dipHeight = CGFloat(size) * 0.17

        let points: [CGPoint] = [
            CGPoint(x: minX, y: midY),
            CGPoint(x: minX + width * 0.12, y: midY),
            CGPoint(x: minX + width * 0.20, y: midY + spikeHeight),
            CGPoint(x: minX + width * 0.28, y: midY - dipHeight),
            CGPoint(x: minX + width * 0.36, y: midY),
            CGPoint(x: minX + width * 0.48, y: midY),
            CGPoint(x: minX + width * 0.56, y: midY + spikeHeight * 1.05),
            CGPoint(x: minX + width * 0.64, y: midY - dipHeight * 1.05),
            CGPoint(x: minX + width * 0.72, y: midY),
            CGPoint(x: maxX, y: midY)
        ]

        if let first = points.first {
            wavePath.move(to: first)
        }
        for point in points.dropFirst() {
            wavePath.line(to: point)
        }
        wavePath.lineCapStyle = .round
        wavePath.lineJoinStyle = .round

        cgContext?.saveGState()
        cgContext?.setShadow(
            offset: .zero,
            blur: CGFloat(size) * 0.06,
            color: NSColor(calibratedRed: 0.2, green: 0.9, blue: 1, alpha: 0.6).cgColor
        )
        NSColor(calibratedRed: 0.2, green: 0.9, blue: 1, alpha: 0.9).setStroke()
        wavePath.lineWidth = CGFloat(size) * 0.035
        wavePath.stroke()
        cgContext?.restoreGState()

        NSColor(calibratedRed: 0.72, green: 0.98, blue: 1, alpha: 1).setStroke()
        wavePath.lineWidth = CGFloat(size) * 0.02
        wavePath.stroke()

        NSGraphicsContext.restoreGraphicsState()

        if let data = rep.representation(using: .png, properties: [:]) {
            try data.write(to: outputURL)
        }
    }
}

let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
try IconRenderer.render(size: 1024, outputURL: baseURL.appendingPathComponent("app_icon.png"))
try IconRenderer.render(size: 1024, outputURL: baseURL.appendingPathComponent("installer_icon.png"))
print("Generated app_icon.png and installer_icon.png")
