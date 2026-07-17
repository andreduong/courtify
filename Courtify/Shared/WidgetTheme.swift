import SwiftUI

enum WidgetTheme {
    static let midnightGreen = Color(hex: 0x0A120D)
    static let opticYellow = Color(hex: 0xCCFF00)
    static let emeraldGreen = Color(hex: 0x00703C)
    static let courtGreen = Color(hex: 0x35C77F)

    /// Tuned for F1-style density while clearing continuous corner masks.
    static let contentInset: CGFloat = 16

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
    var hatchOpacity: Double = 0.07

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

            // Soft radial glow — stadium-light feel without flat washes
            RadialGradient(
                colors: [accent.opacity(glowOpacity), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 160
            )
            .blendMode(.plusLighter)
            .opacity(0.55)

            WidgetHatchOverlay(opacity: hatchOpacity)
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

func widgetSurfaceGradient(for event: TournamentEvent?) -> some View {
    WidgetAtmosphere(accent: WidgetTheme.surfaceAccent(for: event?.surface))
}

func rankingsAtmosphere(for tour: TourPreference) -> some View {
    WidgetAtmosphere(
        accent: tour == .wta ? Color(hex: 0x5A2D78) : Color(hex: 0x0C3A5C),
        glowOpacity: 0.45
    )
}
