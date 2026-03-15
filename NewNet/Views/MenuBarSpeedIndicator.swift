import AppKit

final class MenuBarSpeedIndicator: NSView {
    var snapshot: NetworkSpeedSnapshot = .zero {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    var preferredWidth: CGFloat {
        ceil(contentWidth)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if snapshot.downloadBytesPerSecond <= 0, snapshot.uploadBytesPerSecond <= 0 {
            drawIdleState(in: bounds)
            return
        }

        drawActiveState(in: bounds)
    }

    private let horizontalInset: CGFloat = 6
    private let activeLineSpacing: CGFloat = -1

    private var idleFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }

    private var activeFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    }

    private var uploadText: String {
        "\(ByteCountFormatter.menuBarSpeedString(for: snapshot.uploadBytesPerSecond))↑"
    }

    private var downloadText: String {
        "\(ByteCountFormatter.menuBarSpeedString(for: snapshot.downloadBytesPerSecond))↓"
    }

    private var contentWidth: CGFloat {
        if snapshot.downloadBytesPerSecond <= 0, snapshot.uploadBytesPerSecond <= 0 {
            return measuredWidth(for: "0", font: idleFont) + (horizontalInset * 2)
        }

        let widestLine = max(
            measuredWidth(for: uploadText, font: activeFont),
            measuredWidth(for: downloadText, font: activeFont)
        )

        return widestLine + (horizontalInset * 2)
    }

    private func drawIdleState(in rect: NSRect) {
        let text = NSAttributedString(string: "0", attributes: textAttributes(for: idleFont))
        let size = text.size()
        let drawRect = NSRect(
            x: rect.maxX - horizontalInset - size.width,
            y: floor((rect.height - size.height) / 2),
            width: size.width,
            height: size.height
        )

        text.draw(in: drawRect)
    }

    private func drawActiveState(in rect: NSRect) {
        let topText = NSAttributedString(string: uploadText, attributes: textAttributes(for: activeFont))
        let bottomText = NSAttributedString(string: downloadText, attributes: textAttributes(for: activeFont))

        let topSize = topText.size()
        let bottomSize = bottomText.size()
        let totalHeight = topSize.height + bottomSize.height + activeLineSpacing
        let startY = floor((rect.height - totalHeight) / 2)

        let topRect = NSRect(
            x: rect.maxX - horizontalInset - topSize.width,
            y: startY,
            width: topSize.width,
            height: topSize.height
        )

        let bottomRect = NSRect(
            x: rect.maxX - horizontalInset - bottomSize.width,
            y: startY + topSize.height + activeLineSpacing,
            width: bottomSize.width,
            height: bottomSize.height
        )

        topText.draw(in: topRect)
        bottomText.draw(in: bottomRect)
    }

    private func textAttributes(for font: NSFont) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byClipping

        return [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func measuredWidth(for text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
