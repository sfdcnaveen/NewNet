import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    enum Radius {
        static let chip: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let panel: CGFloat = 22
    }
    
    enum Animation {
        /// Used for subtle hover and press states
        static let hover = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 0.75, blendDuration: 0.1)
        
        /// Used for layout changes, insertion, and state transitions
        static let transition = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.82, blendDuration: 0.15)
        
        /// Used for fluid tab morphing and matched geometry transitions
        static let tabMorph = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2)
        
        /// Used for progress bar movement
        static let progress = SwiftUI.Animation.interactiveSpring(response: 0.28, dampingFraction: 0.82)
    }
}

// MARK: - Liquid Glass Panel Modifier

struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
        
        if reduceTransparency {
            content
                .background {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                }
        } else {
            content
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.strokeBorder(specularGradient, lineWidth: 1)
                }
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12),
                    radius: 20,
                    x: 0,
                    y: 8
                )
        }
    }

    private var specularGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: colorScheme == .dark ? Color.white.opacity(0.60) : Color.white.opacity(0.90), location: 0.0),
                .init(color: colorScheme == .dark ? Color.cyan.opacity(0.25) : Color.cyan.opacity(0.40), location: 0.25),
                .init(color: colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.35), location: 0.60),
                .init(color: colorScheme == .dark ? Color.purple.opacity(0.15) : Color.purple.opacity(0.25), location: 0.85),
                .init(color: colorScheme == .dark ? Color.white.opacity(0.30) : Color.white.opacity(0.55), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Liquid Glass Card Modifier

struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignTokens.Radius.medium
    var isHovered: Bool = false
    var isActive: Bool = false
    var tint: Color? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        if reduceTransparency {
            content
                .background {
                    shape.fill(opaqueFill)
                }
        } else if let tint = tint {
            content
                .glassEffect(.regular.tint(tint.opacity(isActive ? 0.35 : 0.18)), in: shape)
                .overlay {
                    shape.strokeBorder(strokeGradient, lineWidth: 0.75)
                }
        } else if isActive {
            content
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.25)), in: shape)
                .overlay {
                    shape.strokeBorder(strokeGradient, lineWidth: 0.75)
                }
        } else {
            content
                .glassEffect(.clear, in: shape)
                .overlay {
                    shape.strokeBorder(strokeGradient, lineWidth: 0.75)
                }
        }
    }

    private var opaqueFill: Color {
        if isActive {
            return Color.accentColor.opacity(0.16)
        } else if isHovered {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        } else {
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var strokeGradient: LinearGradient {
        if let tint = tint {
            return LinearGradient(
                colors: [tint.opacity(0.7), tint.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isActive {
            return LinearGradient(
                colors: [Color.accentColor.opacity(0.75), Color.accentColor.opacity(0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isHovered {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.35) : Color.white.opacity(0.75),
                    colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.20) : Color.white.opacity(0.50),
                    colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Liquid Glass Control Modifier

struct LiquidGlassControlModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignTokens.Radius.small
    var isHovered: Bool = false
    var isActive: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        if reduceTransparency {
            content
                .background {
                    shape.fill(opaqueFill)
                }
        } else if isActive {
            content
                .glassEffect(.regular.interactive().tint(Color.accentColor.opacity(0.30)), in: shape)
                .overlay {
                    shape.strokeBorder(Color.accentColor.opacity(0.60), lineWidth: 0.75)
                }
        } else {
            content
                .glassEffect(.clear.interactive(), in: shape)
                .overlay {
                    shape.strokeBorder(strokeColor, lineWidth: 0.75)
                }
        }
    }
    
    private var opaqueFill: Color {
        if isActive {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color(nsColor: .controlBackgroundColor).opacity(0.6)
        }
        return Color(nsColor: .controlBackgroundColor)
    }
    
    private var strokeColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.55)
        } else if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.30) : Color.white.opacity(0.60)
        }
        return colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.35)
    }
}

// MARK: - Liquid Glass Pill Modifier

struct LiquidGlassPillModifier: ViewModifier {
    var tint: Color? = nil
    var isActive: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        
        if reduceTransparency {
            content
                .background {
                    shape.fill(Color(nsColor: .controlBackgroundColor))
                }
        } else if let tint = tint {
            content
                .glassEffect(.regular.tint(tint.opacity(isActive ? 0.35 : 0.15)), in: shape)
                .overlay {
                    shape.strokeBorder(tint.opacity(0.50), lineWidth: 0.75)
                }
        } else if isActive {
            content
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.28)), in: shape)
                .overlay {
                    shape.strokeBorder(Color.accentColor.opacity(0.60), lineWidth: 0.75)
                }
        } else {
            content
                .glassEffect(.clear, in: shape)
                .overlay {
                    shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.40), lineWidth: 0.75)
                }
        }
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var isProminent: Bool = false
    var cornerRadius: CGFloat = DesignTokens.Radius.small
    var isCircular: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isCircular {
                let shape = Circle()
                configuration.label
                    .foregroundStyle(isProminent ? Color.white : (tint ?? Color.primary))
                    .glassEffect(
                        isProminent
                            ? .regular.interactive().tint(tint ?? Color.accentColor)
                            : .clear.interactive(),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(strokeGradient(isPressed: configuration.isPressed), lineWidth: 0.75)
                    }
            } else {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                configuration.label
                    .foregroundStyle(isProminent ? Color.white : (tint ?? Color.primary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(
                        isProminent
                            ? .regular.interactive().tint(tint ?? Color.accentColor)
                            : .clear.interactive(),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(strokeGradient(isPressed: configuration.isPressed), lineWidth: 0.75)
                    }
            }
        }
        .scaleEffect(!reduceMotion && configuration.isPressed ? 0.94 : 1.0)
        .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }

    private func strokeGradient(isPressed: Bool) -> LinearGradient {
        if isProminent {
            return LinearGradient(
                colors: [Color.white.opacity(0.6), Color.white.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                colorScheme == .dark ? Color.white.opacity(isPressed ? 0.40 : 0.25) : Color.white.opacity(0.60),
                colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Media Control Glyph Button Style

struct MediaControlGlyphButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.25 : (isHovering ? 0.16 : 0.0)))
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(isHovering ? 0.35 : 0.0), lineWidth: 0.75)
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.90 : 1.0)
            .onHover { isHovering = $0 }
            .animation(DesignTokens.Animation.hover, value: isHovering)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.92 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func liquidGlassPanel() -> some View {
        modifier(LiquidGlassPanelModifier())
    }
    
    func liquidGlassCard(
        cornerRadius: CGFloat = DesignTokens.Radius.medium,
        isHovered: Bool = false,
        isActive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, isHovered: isHovered, isActive: isActive, tint: tint))
    }
    
    func liquidGlassControl(cornerRadius: CGFloat = DesignTokens.Radius.small, isHovered: Bool = false, isActive: Bool = false) -> some View {
        modifier(LiquidGlassControlModifier(cornerRadius: cornerRadius, isHovered: isHovered, isActive: isActive))
    }
    
    func liquidGlassPill(tint: Color? = nil, isActive: Bool = false) -> some View {
        modifier(LiquidGlassPillModifier(tint: tint, isActive: isActive))
    }
    
    func menuItemBackground() -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: DesignTokens.Radius.medium))
    }
}

