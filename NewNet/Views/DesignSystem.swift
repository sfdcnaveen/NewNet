import SwiftUI

enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let panel: CGFloat = 24
    }
    
    enum Animation {
        /// Used for subtle hover and press states
        static let hover = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0.1)
        
        /// Used for layout changes, insertion, and state transitions
        static let transition = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2)
        
        /// Used for progress bar movement
        static let progress = SwiftUI.Animation.interactiveSpring(response: 0.3, dampingFraction: 0.8)
    }
}

// MARK: - Liquid Glass Modifiers

struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
                    .fill(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.panel, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 20, x: 0, y: 10)
    }
}

struct LiquidGlassControlModifier: ViewModifier {
    var isHovered: Bool = false
    var isActive: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .fill(fillMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }
    
    private var fillMaterial: AnyShapeStyle {
        if reduceTransparency {
            if isActive {
                return AnyShapeStyle(Color.accentColor.opacity(0.15))
            } else if isHovered {
                return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        } else {
            if isActive {
                return AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
            } else if isHovered {
                return AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6))
            }
            return AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4))
        }
    }
    
    private var strokeColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.5)
        } else if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.15)
        }
        return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

struct MenuItemGlassBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .fill(reduceTransparency ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func liquidGlassPanel() -> some View {
        modifier(LiquidGlassPanelModifier())
    }
    
    func liquidGlassControl(isHovered: Bool = false, isActive: Bool = false) -> some View {
        modifier(LiquidGlassControlModifier(isHovered: isHovered, isActive: isActive))
    }
    
    func menuItemBackground() -> some View {
        modifier(MenuItemGlassBackground())
    }
}
