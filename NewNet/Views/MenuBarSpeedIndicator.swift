import AppKit

final class MenuBarSpeedIndicator: NSView {
    var snapshot: NetworkSpeedSnapshot = .zero {
        didSet {
            needsDisplay = true
        }
    }

    var quickText: String? {
        didSet {
            needsDisplay = true
        }
    }

    var isKeepAwakeActive: Bool = false {
        didSet {
            if oldValue != isKeepAwakeActive {
                needsDisplay = true
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Allow clicks to pass through to the status bar button.
        nil
    }

    override var isFlipped: Bool {
        true
    }

    var preferredWidth: CGFloat {
        ceil(contentWidth)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let quickText {
            drawQuickText(quickText, in: bounds)
            return
        }

        if snapshot.downloadBytesPerSecond <= 0, snapshot.uploadBytesPerSecond <= 0 {
            drawIdleState(in: bounds)
            return
        }

        drawActiveState(in: bounds)
    }

    private let horizontalInset: CGFloat = 6
    private let activeLineSpacing: CGFloat = -1
    private let coffeeIconWidth: CGFloat = 14
    private let coffeeIconHeight: CGFloat = 11
    private let coffeeIconSpacing: CGFloat = 4

    private var extraCoffeeWidth: CGFloat {
        isKeepAwakeActive ? (coffeeIconWidth + coffeeIconSpacing) : 0
    }

    private var idleFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }

    private var activeFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    }

    private var quickFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    }

    private var uploadText: String {
        "\(ByteCountFormatter.menuBarSpeedString(for: snapshot.uploadBytesPerSecond))↑"
    }

    private var downloadText: String {
        "\(ByteCountFormatter.menuBarSpeedString(for: snapshot.downloadBytesPerSecond))↓"
    }

    private var contentWidth: CGFloat {
        let baseWidth: CGFloat
        if let quickText {
            baseWidth = measuredWidth(for: quickText, font: quickFont)
        } else if snapshot.downloadBytesPerSecond <= 0, snapshot.uploadBytesPerSecond <= 0 {
            baseWidth = measuredWidth(for: "0", font: idleFont)
        } else {
            baseWidth = max(
                measuredWidth(for: uploadText, font: activeFont),
                measuredWidth(for: downloadText, font: activeFont)
            )
        }

        return baseWidth + (horizontalInset * 2) + extraCoffeeWidth
    }

    private func drawQuickText(_ text: String, in rect: NSRect) {
        let attributed = NSAttributedString(string: text, attributes: textAttributes(for: quickFont))
        let size = attributed.size()
        let drawRect = NSRect(
            x: rect.maxX - horizontalInset - extraCoffeeWidth - size.width,
            y: floor((rect.height - size.height) / 2),
            width: size.width,
            height: size.height
        )
        attributed.draw(in: drawRect)
        drawCoffeeIcon(in: rect)
    }

    private func drawIdleState(in rect: NSRect) {
        let text = NSAttributedString(string: "0", attributes: textAttributes(for: idleFont))
        let size = text.size()
        let drawRect = NSRect(
            x: rect.maxX - horizontalInset - extraCoffeeWidth - size.width,
            y: floor((rect.height - size.height) / 2),
            width: size.width,
            height: size.height
        )

        text.draw(in: drawRect)
        drawCoffeeIcon(in: rect)
    }

    private func drawActiveState(in rect: NSRect) {
        let topText = NSAttributedString(string: uploadText, attributes: textAttributes(for: activeFont))
        let bottomText = NSAttributedString(string: downloadText, attributes: textAttributes(for: activeFont))

        let topSize = topText.size()
        let bottomSize = bottomText.size()
        let totalHeight = topSize.height + bottomSize.height + activeLineSpacing
        let startY = floor((rect.height - totalHeight) / 2)

        let topRect = NSRect(
            x: rect.maxX - horizontalInset - extraCoffeeWidth - topSize.width,
            y: startY,
            width: topSize.width,
            height: topSize.height
        )

        let bottomRect = NSRect(
            x: rect.maxX - horizontalInset - extraCoffeeWidth - bottomSize.width,
            y: startY + topSize.height + activeLineSpacing,
            width: bottomSize.width,
            height: bottomSize.height
        )

        topText.draw(in: topRect)
        bottomText.draw(in: bottomRect)
        drawCoffeeIcon(in: rect)
    }

    private func drawCoffeeIcon(in rect: NSRect) {
        guard isKeepAwakeActive else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.labelColor]))
        guard let image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Keep Awake Active")?.withSymbolConfiguration(config) else {
            return
        }
        let iconRect = NSRect(
            x: rect.maxX - horizontalInset - coffeeIconWidth,
            y: floor((rect.height - coffeeIconHeight) / 2),
            width: coffeeIconWidth,
            height: coffeeIconHeight
        )
        image.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
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
