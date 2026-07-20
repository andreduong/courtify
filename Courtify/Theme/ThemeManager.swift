import SwiftUI

enum ThemeManager {
    // MARK: - Brand Colors

    /// Canonical Courtify midnight green (also the default app-theme preset).
    static let midnightGreen = Color(hex: 0x0A120D)
    static let opticYellow = Color(hex: 0xCCFF00)
    static let emeraldGreen = Color(hex: 0x00703C)
    /// Brighter green for accent text on dark tiles (subtitles, highlights).
    static let courtGreen = Color(hex: 0x35C77F)

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

// MARK: - App appearance (Premium)

enum AppThemePreset: String, CaseIterable, Identifiable {
    case courtify
    case midnight
    case hardcourt
    case clay
    case grass
    case berry
    case carbon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .courtify: "Courtify"
        case .midnight: "Midnight"
        case .hardcourt: "Hard court"
        case .clay: "Clay"
        case .grass: "Grass"
        case .berry: "Berry"
        case .carbon: "Carbon"
        }
    }

    var hex: UInt {
        switch self {
        case .courtify: 0x0A120D
        case .midnight: 0x050808
        case .hardcourt: 0x0C2340
        case .clay: 0x2A120C
        case .grass: 0x0C1F12
        case .berry: 0x1A1024
        case .carbon: 0x101214
        }
    }

    var color: Color { Color(hex: hex) }

    /// Highlights — stars, ranking labels, primary buttons, countdown accents.
    var accentHex: UInt {
        switch self {
        case .courtify: 0xCCFF00
        case .midnight: 0xCCFF00
        case .hardcourt: 0x4A90D9
        case .clay: 0xE35205
        case .grass: 0x35C77F
        case .berry: 0x9B6BFF
        case .carbon: 0xB8C0C8
        }
    }

    /// Hero / widget gradient lift atop the canvas.
    var liftHex: UInt {
        switch self {
        case .courtify: 0x00703C
        case .midnight: 0x1A2820
        case .hardcourt: 0x1A4A78
        case .clay: 0x8A2E05
        case .grass: 0x0A4A28
        case .berry: 0x4A2868
        case .carbon: 0x2A3238
        }
    }

    var accentColor: Color { Color(hex: accentHex) }
    var liftColor: Color { Color(hex: liftHex) }
}

enum LogoBallPreset: String, CaseIterable, Identifiable {
    case courtify
    case hardcourt
    case clay
    case grass
    case berry
    case white
    case optic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .courtify: "Courtify"
        case .hardcourt: "Hard court"
        case .clay: "Clay"
        case .grass: "Grass"
        case .berry: "Berry"
        case .white: "White"
        case .optic: "Optic"
        }
    }

    var hex: UInt {
        switch self {
        case .courtify: AppThemePreset.courtify.accentHex
        case .hardcourt: 0x4A90D9
        case .clay: 0xE35205
        case .grass: 0x006633
        case .berry: 0x9B6BFF
        case .white: 0xFFFFFF
        case .optic: 0xCCFF00
        }
    }

    var color: Color { Color(hex: hex) }
}

@MainActor
final class AppAppearanceStore: ObservableObject {
    static let shared = AppAppearanceStore()

    @Published private(set) var theme: AppThemePreset
    @Published private(set) var logoBall: LogoBallPreset

    var canvasColor: Color { theme.color }
    var accentColor: Color { theme.accentColor }
    var liftColor: Color { theme.liftColor }
    var logoBallColor: Color { logoBall.color }

    private init() {
        let themeRaw = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.appThemePreset)
        theme = AppThemePreset(rawValue: themeRaw ?? "") ?? .courtify
        let ballRaw = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.logoBallPreset)
        logoBall = LogoBallPreset(rawValue: ballRaw ?? "") ?? .courtify
    }

    func setTheme(_ preset: AppThemePreset) {
        guard theme != preset else { return }
        theme = preset
        AppGroupConstants.userDefaults.set(preset.rawValue, forKey: AppGroupConstants.Keys.appThemePreset)
        NotificationCenter.default.post(name: AppGroupConstants.appAppearanceDidChange, object: nil)
    }

    func setLogoBall(_ preset: LogoBallPreset) {
        guard logoBall != preset else { return }
        logoBall = preset
        AppGroupConstants.userDefaults.set(preset.rawValue, forKey: AppGroupConstants.Keys.logoBallPreset)
        AppIconManager.applyLogoBall(preset)
        NotificationCenter.default.post(name: AppGroupConstants.appAppearanceDidChange, object: nil)
    }
}

// MARK: - View Modifiers

/// Emerald → app canvas gradient (Rankings, Schedule hero tops).
struct CourtifyHeroBackground: View {
    var topOpacity: Double = 0.95
    var midOpacity: Double = 0.5
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        LinearGradient(
            colors: [
                appearance.liftColor.opacity(topOpacity),
                appearance.liftColor.opacity(midOpacity),
                appearance.canvasColor,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Full-screen canvas with optional soft emerald wash (share screen, modals).
struct CourtifyThemeBackdrop: View {
    var heroWash: Bool = false
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        ZStack {
            appearance.canvasColor.ignoresSafeArea()
            if heroWash {
                LinearGradient(
                    colors: [
                        appearance.liftColor.opacity(0.35),
                        appearance.canvasColor,
                        appearance.canvasColor,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }
}

struct CourtifyThemedNavigationBar: ViewModifier {
    @ObservedObject private var appearance = AppAppearanceStore.shared

    func body(content: Content) -> some View {
        content.toolbarBackground(appearance.canvasColor, for: .navigationBar)
    }
}

struct CourtifyBackground: ViewModifier {
    @ObservedObject private var appearance = AppAppearanceStore.shared

    func body(content: Content) -> some View {
        ZStack {
            appearance.canvasColor.ignoresSafeArea()
            content
        }
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

    func courtifyThemedNavigationBar() -> some View {
        modifier(CourtifyThemedNavigationBar())
    }

    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
