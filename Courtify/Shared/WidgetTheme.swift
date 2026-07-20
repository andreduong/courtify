import SwiftUI

enum WidgetTheme {
    static let midnightGreen = Color(hex: 0x0A120D)
    static let opticYellow = Color(hex: 0xCCFF00)
    static let emeraldGreen = Color(hex: 0x00703C)
    static let courtGreen = Color(hex: 0x35C77F)

    /// Tuned for F1-style density while clearing continuous corner masks.
    static let contentInset: CGFloat = 16
    /// Extra bottom inset so copy / lists clear the “made by courtify” stamp.
    /// Keep modest — large values clip ranks / scores inside 165pt small widgets.
    static let stampClearance: CGFloat = 14

    /// Home-screen widget content insets (full-bleed bg + stamp-safe bottom).
    static var contentInsets: EdgeInsets {
        EdgeInsets(
            top: contentInset,
            leading: contentInset,
            bottom: contentInset + stampClearance,
            trailing: contentInset
        )
    }

    // MARK: Typography — mix heavy display numerals with rounded labels

    /// Big ranks, countdowns, scores — default design reads more “sports broadcast”.
    static func displayFont(size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func roundedFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    static func roundedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: Surface accents (tournament brand — no muddy logos)

    static func surfaceAccent(for surface: String?) -> Color {
        switch surface {
        case "Clay": Color(hex: 0xE35205)
        case "Grass": Color(hex: 0x1FA64A)
        case "Hard": Color(hex: 0x1A8FD6)
        default: emeraldGreen
        }
    }

    static func surfaceAccentHex(for surface: String?) -> UInt {
        switch surface {
        case "Clay": 0xE35205
        case "Grass": 0x1FA64A
        case "Hard": 0x1A8FD6
        default: 0x00703C
        }
    }

    static func tourAccent(for tour: TourPreference) -> Color {
        tour == .wta ? Color(hex: 0x7B3FA0) : Color(hex: 0x1A6B9A)
    }

    static func ordinalRank(_ ranking: Int?) -> String {
        guard let ranking, ranking > 0 else { return "—" }
        switch ranking {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(ranking)th"
        }
    }
}

// MARK: - Atmospheric backgrounds (gradients + texture, no logos)

struct WidgetAtmosphere: View {
    let accent: Color
    var secondary: Color = WidgetTheme.midnightGreen
    var glowOpacity: Double = 0.55
    var texture: WidgetTexturePreset = .aurora

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent,
                    accent.opacity(0.72),
                    secondary.opacity(0.95),
                    WidgetTheme.midnightGreen,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WidgetTextureOverlay(texture: texture, accent: accent, glowOpacity: glowOpacity)
        }
    }
}

/// Per-widget texture layer used on colorable cards (favorite, standings, live, order).
struct WidgetTextureOverlay: View {
    let texture: WidgetTexturePreset
    var accent: Color = WidgetTheme.emeraldGreen
    var glowOpacity: Double = 0.55

    var body: some View {
        switch texture {
        case .aurora:
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(min(1, glowOpacity + 0.2)), accent.opacity(0.25), .clear],
                    center: .topTrailing,
                    startRadius: 2,
                    endRadius: 190
                )
                .blendMode(.plusLighter)
                .opacity(0.85)

                RadialGradient(
                    colors: [Color.white.opacity(0.18), WidgetTheme.opticYellow.opacity(0.08), .clear],
                    center: .bottomLeading,
                    startRadius: 2,
                    endRadius: 150
                )
                .blendMode(.plusLighter)
                .opacity(0.7)

                RadialGradient(
                    colors: [accent.opacity(0.35), .clear],
                    center: UnitPoint(x: 0.15, y: 0.2),
                    startRadius: 4,
                    endRadius: 110
                )
                .blendMode(.plusLighter)
                .opacity(0.55)

                LinearGradient(
                    colors: [.clear, WidgetTheme.midnightGreen.opacity(0.28)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)

        case .spotlight:
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(min(1, glowOpacity + 0.15)), .clear],
                    center: UnitPoint(x: 0.82, y: 0.12),
                    startRadius: 2,
                    endRadius: 190
                )
                .blendMode(.plusLighter)
                .opacity(0.85)

                RadialGradient(
                    colors: [Color.black.opacity(0.45), .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 160
                )
            }
            .allowsHitTesting(false)

        case .carbon:
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(glowOpacity * 0.55), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 150
                )
                .blendMode(.plusLighter)
                .opacity(0.45)
                WidgetHatchOverlay(opacity: 0.075)
            }
            .allowsHitTesting(false)

        case .mesh:
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(glowOpacity * 0.5), .clear],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 140
                )
                .blendMode(.plusLighter)
                .opacity(0.5)
                WidgetMeshOverlay(opacity: 0.09)
            }
            .allowsHitTesting(false)

        case .velvet:
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(glowOpacity * 0.7), accent.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: 180
                )
                .blendMode(.plusLighter)
                .opacity(0.65)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        .clear,
                        WidgetTheme.midnightGreen.opacity(0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
        }
    }
}

/// Subtle diagonal hatch — carbon / string texture without competing with copy.
struct WidgetHatchOverlay: View {
    var opacity: Double = 0.08
    var lineSpacing: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let size = max(geo.size.width, geo.size.height) * 1.6
                var x: CGFloat = -size
                while x < size * 2 {
                    path.move(to: CGPoint(x: x, y: -20))
                    path.addLine(to: CGPoint(x: x + size, y: size + 20))
                    x += lineSpacing
                }
            }
            .stroke(Color.white.opacity(opacity), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// Fine orthogonal mesh — quieter than carbon fiber.
struct WidgetMeshOverlay: View {
    var opacity: Double = 0.08
    var spacing: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            Path { path in
                var x: CGFloat = 0
                while x <= geo.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= geo.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.white.opacity(opacity), lineWidth: 0.45)
        }
        .allowsHitTesting(false)
    }
}

/// Thin vertical brand bar used on standings rows (F1 team-color cue → tour/surface).
struct WidgetAccentBar: View {
    let color: Color
    var width: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(width: width)
            .frame(maxHeight: .infinity)
    }
}

@ViewBuilder
func widgetSurfaceGradient(for event: TournamentEvent?) -> some View {
    if let slam = grandSlamMatching(event) {
        widgetSlamAtmosphere(slam)
    } else {
        WidgetAtmosphere(accent: WidgetTheme.surfaceAccent(for: event?.surface), texture: .aurora)
    }
}

func widgetSlamAtmosphere(_ slam: GrandSlam) -> WidgetAtmosphere {
    let accent = Color(hex: slam.accentColor)
    let secondary: Color = {
        switch slam {
        case .australianOpen: Color(hex: 0x1E6FA8) // deeper blue under sky blue
        case .frenchOpen: Color(hex: 0x8A2E05) // burnt clay
        case .wimbledon: Color(hex: slam.highlightColor) // purple → green
        case .usOpen: Color(hex: 0x061018) // near-black under night blue (yellow via UI accents)
        }
    }()
    return WidgetAtmosphere(
        accent: accent,
        secondary: secondary,
        glowOpacity: slam == .australianOpen || slam == .usOpen ? 0.42 : 0.55,
        texture: .aurora
    )
}

func grandSlamMatching(_ event: TournamentEvent?) -> GrandSlam? {
    guard let event, event.tier == .grandSlam else { return nil }
    return GrandSlam.allCases.first {
        event.name.localizedCaseInsensitiveContains($0.rawValue)
            || (event.shortName == "AO" && $0 == .australianOpen)
            || (event.shortName == "RG" && $0 == .frenchOpen)
            || (event.shortName == "WIM" && $0 == .wimbledon)
            || (event.shortName == "USO" && $0 == .usOpen)
    }
}

/// Background for colorable widgets — Tournament theme keeps slam/surface atmosphere;
/// otherwise uses the saved accent gradient + texture.
struct WidgetStyledBackground: View {
    let widgetID: String
    var event: TournamentEvent? = nil
    var forceSlam: GrandSlam? = nil
    /// Season calendar’s bundled tournament look (deep green velvet) when on Tournament theme.
    var usesCalendarTournamentLook = false
    var startPoint: UnitPoint = .top
    var endPoint: UnitPoint = .bottom
    var fallbackAccent: Color = WidgetTheme.emeraldGreen

    var body: some View {
        let config = WidgetColorStyle.config(for: widgetID)
        ZStack {
            if config.isTournament {
                if let forceSlam {
                    widgetSlamAtmosphere(forceSlam)
                } else if usesCalendarTournamentLook {
                    WidgetAtmosphere(
                        accent: Color(hex: 0x143D2B),
                        glowOpacity: 0.35,
                        texture: .velvet
                    )
                } else {
                    widgetSurfaceGradient(for: event)
                }
            } else {
                WidgetColorStyle.gradient(
                    for: widgetID,
                    fallbackAccent: fallbackAccent,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                WidgetTextureOverlay(
                    texture: config.resolvedTexture,
                    accent: config.resolvedAccent
                )
            }
        }
    }
}

func rankingsAtmosphere(for tour: TourPreference) -> some View {
    WidgetAtmosphere(
        accent: tour == .wta ? Color(hex: 0x5A2D78) : Color(hex: 0x0C3A5C),
        glowOpacity: 0.45,
        texture: .aurora
    )
}
