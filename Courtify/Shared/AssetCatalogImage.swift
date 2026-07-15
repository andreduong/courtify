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
