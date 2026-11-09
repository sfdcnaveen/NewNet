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

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
        
        content
            .clipShape(shape)
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    shape
                        .fill(.regularMaterial)
                        .glassEffect(in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(specularGradient, lineWidth: 1)
            }
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12),
                radius: 24,
                x: 0,
                y: 10
            )
    }

    private var specularGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: colorScheme == .dark ? Color.white.opacity(0.24) : Color.white.opacity(0.75), location: 0.0),
                .init(color: colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.25), location: 0.4),
                .init(color: colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.06), location: 1.0)
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

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        content
            .background {
                if reduceTransparency {
                    shape.fill(opaqueFill)
                } else {
                    shape
                        .fill(materialFill)
                        .glassEffect(glassVariant, in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(strokeGradient, lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(isHovered ? (colorScheme == .dark ? 0.25 : 0.08) : 0),
                radius: isHovered ? 8 : 0,
                x: 0,
                y: isHovered ? 3 : 0
            )
    }

    private var glassVariant: Glass {
        if let tint = tint {
            return .regular.tint(tint)
        } else if isActive {
            return .regular.tint(Color.accentColor)
        } else {
            return .regular
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

    private var materialFill: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
        } else if isHovered {
            return AnyShapeStyle(.ultraThinMaterial)
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private var strokeGradient: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [Color.accentColor.opacity(0.65), Color.accentColor.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isHovered {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.30) : Color.white.opacity(0.85),
                    colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.60),
                    colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.06)
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

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        content
            .background {
                if reduceTransparency {
                    shape.fill(opaqueFill)
                } else {
                    shape
                        .fill(materialFill)
                        .glassEffect(isActive ? .regular.tint(Color.accentColor).interactive() : .regular.interactive(), in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(strokeColor, lineWidth: 1)
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

    private var materialFill: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
        } else if isHovered {
            return AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.65))
        }
        return AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35))
    }
    
    private var strokeColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.6)
        } else if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.16)
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
}

// MARK: - Liquid Glass Pill Modifier

struct LiquidGlassPillModifier: ViewModifier {
    var tint: Color? = nil
    var isActive: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = Capsule()
        
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .controlBackgroundColor))
                } else {
                    shape
                        .fill(pillFill)
                        .glassEffect(tint != nil ? .regular.tint(tint!) : .regular, in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(pillStroke, lineWidth: 1)
            }
    }

    private var pillFill: some ShapeStyle {
        if let tint = tint {
            return AnyShapeStyle(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
        } else if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
        }
        return AnyShapeStyle(Color.primary.opacity(0.06))
    }

    private var pillStroke: Color {
        if let tint = tint {
            return tint.opacity(0.4)
        } else if isActive {
            return Color.accentColor.opacity(0.5)
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var isProminent: Bool = false
    var cornerRadius: CGFloat = DesignTokens.Radius.small
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        configuration.label
            .background {
                shape
                    .fill(backgroundFill(isPressed: configuration.isPressed))
                    .glassEffect(glassStyle(isPressed: configuration.isPressed), in: shape)
            }
            .overlay {
                shape.strokeBorder(strokeGradient(isPressed: configuration.isPressed), lineWidth: 1)
            }
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }

    private func glassStyle(isPressed: Bool) -> Glass {
        if isProminent {
            return .regular.tint(tint ?? Color.accentColor).interactive()
        }
        return .regular.interactive()
    }

    private func backgroundFill(isPressed: Bool) -> some ShapeStyle {
        if isProminent {
            let base = tint ?? Color.accentColor
            return AnyShapeStyle(base.opacity(isPressed ? 0.85 : 0.95))
        }
        if isPressed {
            return AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.60))
        }
        return AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40))
    }

    private func strokeGradient(isPressed: Bool) -> LinearGradient {
        if isProminent {
            return LinearGradient(
                colors: [Color.white.opacity(0.4), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                colorScheme == .dark ? Color.white.opacity(isPressed ? 0.35 : 0.20) : Color.white.opacity(0.70),
                colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

