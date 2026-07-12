import SwiftUI

enum ThemeManager {
    // MARK: - Brand Colors

    static let midnightGreen = Color(hex: 0x0A120D)
    static let opticYellow = Color(hex: 0xCCFF00)
    static let emeraldGreen = Color(hex: 0x00703C)

    // MARK: - Typography

    static func roundedFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    static func roundedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Glassmorphism

    static var glassCard: some ShapeStyle {
        .ultraThinMaterial
    }

    static func glassCard(cornerRadius: CGFloat = 20) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers

struct CourtifyBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ThemeManager.opticYellow.opacity(0.15), lineWidth: 1)
            }
    }
}

extension View {
    func courtifyBackground() -> some View {
        modifier(CourtifyBackground())
    }

    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
