import SwiftUI

enum PlayerSilhouetteStyle {
    case headshot
    case torso
}

/// Neutral fallback when bundled or API player photos are unavailable.
/// One symbol for both tours: `figure.tennis` (a player mid-serve).
/// `figure.dress.line.vertical.figure` is a restroom-pair glyph — never use it.
/// Monochrome glyph; no LinearGradient / grey fill boxes behind the symbol.
struct PlayerSilhouetteView: View {
    let tour: TourPreference
    var style: PlayerSilhouetteStyle = .headshot
    /// Headshot frame diameter, or torso symbol point size when `style == .torso`.
    var size: CGFloat = 44
    /// Torso placement (Home / widgets). Ignored for headshot.
    var alignment: Alignment = .bottomTrailing

    var body: some View {
        Group {
            switch style {
            case .headshot:
                headshotBody
            case .torso:
                torsoBody
            }
        }
    }

    /// List / search avatar: symbol only inside the circular frame (no muddy fill).
    private var headshotBody: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .symbolRenderingMode(.monochrome)
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }

    /// Home / widget torso placeholder: monochrome SF Symbol only — no fill wash.
    private var torsoBody: some View {
        // Default `size` (44) is the headshot diameter; torso callers pass an explicit point size.
        let symbolSize = size == 44 ? 120 : size
        return Image(systemName: symbolName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.white.opacity(0.28))
            .symbolRenderingMode(.monochrome)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.trailing, alignment == .bottomTrailing || alignment == .trailing ? 4 : 0)
            .padding(.leading, alignment == .bottomLeading || alignment == .leading ? 4 : 0)
            .padding(.bottom, 2)
            .allowsHitTesting(false)
    }

    /// `figure.tennis` for every tour — the old WTA restroom-pair glyph read as
    /// a bathroom sign next to real cutouts (user-reported, Jul 2026).
    private var symbolName: String {
        "figure.tennis"
    }
}
