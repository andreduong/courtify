import SwiftUI

enum PlayerSilhouetteStyle {
    case headshot
    case torso
}

/// Neutral ATP/WTA fallback when bundled or API player photos are unavailable.
struct PlayerSilhouetteView: View {
    let tour: TourPreference
    var style: PlayerSilhouetteStyle = .headshot
    var size: CGFloat = 44

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

    private var headshotBody: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
            Image(systemName: symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var torsoBody: some View {
        Image(systemName: symbolName)
            .font(.system(size: 120, weight: .semibold))
            .foregroundStyle(.white.opacity(0.28))
            .symbolRenderingMode(.monochrome)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 4)
            .padding(.bottom, 2)
            .allowsHitTesting(false)
    }

    private var symbolName: String {
        switch tour {
        case .wta:
            return "figure.dress.line.vertical.figure"
        case .atp, .both:
            return "figure.tennis"
        }
    }
}
