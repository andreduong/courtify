import SwiftUI

/// Loads images directly from the asset catalog (no in-memory cache).
/// Use for tournament logos and other assets that must reflect catalog updates immediately.
struct AssetCatalogImage: View {
    let name: String
    var contentMode: ContentMode = .fill

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}

/// Uniform circular badge for Grand Slam logos — the four marks ship in wildly
/// different shapes (AO square tile, USO wide wordmark, RG/WIM roundels), so
/// `scaledToFill` inside a brand-tinted circle is the only treatment that reads
/// consistently. Use everywhere a slam logo appears in a row or card.
struct SlamLogoBadge: View {
    let slam: GrandSlam
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(badgeBackground)

            AssetCatalogImage(name: slam.logoImageName, contentMode: .fill)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var badgeBackground: Color {
        switch slam {
        case .australianOpen: Color(hex: 0x0085CA).opacity(0.35)
        case .frenchOpen: Color(hex: 0xE35205).opacity(0.25)
        case .wimbledon: Color(hex: 0x006633).opacity(0.3)
        case .usOpen: Color(hex: 0x0C2340)
        }
    }
}
