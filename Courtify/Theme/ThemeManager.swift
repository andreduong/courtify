import SwiftUI

enum ThemeManager {
    // MARK: - Brand Colors

    /// Pure OLED screen canvas — all main surfaces sit on this, not flat gray/green fills.
    static let oledBlack = Color.black
    /// Legacy brand midnight (Settings swatches / widget fallbacks); screens use `oledBlack`.
    static let midnightGreen = Color(hex: 0x0A120D)
    /// Neon active / highlight — tab selection, countdowns, CTAs.
    static let opticYellow = Color(hex: 0xCCFF00)
    /// Alias for paywall / tab chrome (“brand yellow”).
    static let brandYellow = opticYellow
    static let emeraldGreen = Color(hex: 0x00703C)
    /// Alias for ambient blooms / glass refraction washes.
    static let brandGreen = emeraldGreen
    /// Brighter green for accent text on dark tiles (subtitles, highlights).
    static let courtGreen = Color(hex: 0x35C77F)

    /// Hairline edge on frosted glass surfaces (physical light-catch).
    static let glassEdge = Color.white.opacity(0.15)
    static let glassEdgeWidth: CGFloat = 0.5
    /// Secondary glass-pill stroke (Skip / Not now).
    static let glassPillEdge = Color.white.opacity(0.20)

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

    /// Swatch color in Settings — ambient glow uses `liftHex` / `accentHex` on OLED black.
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

    /// Ambient glow / hero wash atop OLED black.
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

    /// Settings swatch / legacy theme chip — not the screen fill.
    var canvasColor: Color { theme.color }
    /// Every main screen canvas is pure OLED black; color comes from ambient glow.
    var screenBackground: Color { ThemeManager.oledBlack }
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

// MARK: - Ambient glow (neon on OLED)

/// Soft brand-colored bloom behind headers / player profiles — reads as neon light on a dark wall.
struct CourtifyAmbientGlow: View {
    var primary: Color
    var secondary: Color? = nil
    var intensity: Double = 1.0
    /// `.top` = header wash; `.trailing` = player profile bloom; `.center` = modal wash.
    var anchor: UnitPoint = .top

    var body: some View {
        ZStack {
            ThemeManager.oledBlack

            if #available(iOS 18.0, *) {
                meshBloom
                    .blur(radius: 120)
                    .opacity(0.9 * intensity)
            }

            // Always layer radial blooms — Mesh alone can read muddy; radials keep the neon spot.
            radialBloom
                .blur(radius: 120)
                .opacity(intensity)
        }
        .allowsHitTesting(false)
    }

    @available(iOS 18.0, *)
    private var meshBloom: some View {
        let glow = secondary ?? primary
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, 0.5),
                SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0),
            ],
            colors: meshColors(primary: primary, secondary: glow)
        )
        .scaleEffect(1.2)
    }

    private var radialBloom: some View {
        let glow = secondary ?? primary
        return ZStack {
            // Tight neon core — spotlight, not a full-screen wash
            RadialGradient(
                colors: [
                    glow.opacity(0.9),
                    primary.opacity(0.55),
                    primary.opacity(0.18),
                    .clear,
                ],
                center: anchor,
                startRadius: 4,
                endRadius: 160
            )

            // Soft wall spill — stays localized after blur
            RadialGradient(
                colors: [
                    primary.opacity(0.4),
                    primary.opacity(0.12),
                    .clear,
                ],
                center: secondaryCenter,
                startRadius: 30,
                endRadius: 260
            )
        }
    }

    private var secondaryCenter: UnitPoint {
        if anchor == .top { return .topTrailing }
        if anchor == .trailing { return .center }
        if anchor == .bottom { return .bottomLeading }
        return .center
    }

    private func meshColors(primary: Color, secondary: Color) -> [Color] {
        if anchor == .trailing {
            return [
                .clear, primary.opacity(0.15), primary.opacity(0.55),
                .clear, secondary.opacity(0.35), primary.opacity(0.4),
                .clear, .clear, secondary.opacity(0.2),
            ]
        }
        if anchor == .bottom {
            return [
                .clear, .clear, .clear,
                primary.opacity(0.2), secondary.opacity(0.35), .clear,
                primary.opacity(0.55), secondary.opacity(0.4), primary.opacity(0.25),
            ]
        }
        return [
            primary.opacity(0.65), secondary.opacity(0.45), primary.opacity(0.35),
            secondary.opacity(0.3), primary.opacity(0.2), .clear,
            .clear, .clear, .clear,
        ]
    }
}

/// Emerald/brand ambient wash → OLED black (Rankings, Schedule, Home heroes).
struct CourtifyHeroBackground: View {
    var topOpacity: Double = 0.95
    var midOpacity: Double = 0.5
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        CourtifyAmbientGlow(
            primary: appearance.liftColor,
            secondary: appearance.accentColor,
            intensity: max(topOpacity, midOpacity),
            anchor: .top
        )
    }
}

/// Full-screen OLED canvas with optional soft brand wash (share screen, modals).
struct CourtifyThemeBackdrop: View {
    var heroWash: Bool = false
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        ZStack {
            ThemeManager.oledBlack.ignoresSafeArea()
            if heroWash {
                CourtifyAmbientGlow(
                    primary: appearance.liftColor,
                    secondary: appearance.accentColor,
                    intensity: 0.55,
                    anchor: .top
                )
                .ignoresSafeArea()
            }
        }
    }
}

/// Massive soft radial bloom behind list/grid glass cards — light for material to refract.
struct CourtifyListAmbientBloom: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Large soft discs retain luminosity after heavy blur better than thin gradients.
                Circle()
                    .fill(ThemeManager.brandYellow.opacity(0.10))
                    .frame(width: w * 1.35, height: w * 1.35)
                    .position(x: w * 0.88, y: h * 0.12)
                    .blur(radius: 120)

                Circle()
                    .fill(ThemeManager.brandGreen.opacity(0.10))
                    .frame(width: w * 1.25, height: w * 1.25)
                    .position(x: w * 0.08, y: h * 0.72)
                    .blur(radius: 120)

                Circle()
                    .fill(ThemeManager.brandYellow.opacity(0.08))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w * 0.55, y: h * 0.45)
                    .blur(radius: 120)
            }
            .frame(width: w, height: h)
        }
        .allowsHitTesting(false)
    }
}

struct CourtifyThemedNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbarBackground(ThemeManager.oledBlack, for: .navigationBar)
    }
}

struct CourtifyBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            ThemeManager.oledBlack.ignoresSafeArea()
            CourtifyListAmbientBloom()
                .ignoresSafeArea()
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
                    .stroke(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
            }
    }
}

/// Frosted glass fill + hairline white edge for cards / list rows (no extra padding).
struct CourtifyGlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Active grid-card chrome: slight scale, brand-yellow rim, soft yellow glow.
struct CourtifySelectableCardModifier: ViewModifier {
    var isSelected: Bool
    var cornerRadius: CGFloat = 18
    var scale: CGFloat = CourtifyMotion.selectedScale

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? ThemeManager.brandYellow : ThemeManager.glassEdge,
                        lineWidth: isSelected ? 1.5 : ThemeManager.glassEdgeWidth
                    )
            }
            .scaleEffect(isSelected ? scale : 1)
            .shadow(
                color: isSelected ? ThemeManager.brandYellow.opacity(0.3) : .clear,
                radius: isSelected ? 15 : 0
            )
            .animation(CourtifyMotion.selection, value: isSelected)
            .sensoryFeedback(.selection, trigger: isSelected) { _, selected in
                selected
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

    func courtifyGlassSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(CourtifyGlassSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Selection chrome for onboarding / grid cards: scale, brand-yellow edge, soft glow.
    func courtifySelectableCard(
        isSelected: Bool,
        cornerRadius: CGFloat = 18,
        scale: CGFloat = CourtifyMotion.selectedScale
    ) -> some View {
        modifier(
            CourtifySelectableCardModifier(
                isSelected: isSelected,
                cornerRadius: cornerRadius,
                scale: scale
            )
        )
    }
}
