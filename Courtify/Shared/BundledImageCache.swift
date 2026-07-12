import UIKit
import SwiftUI

/// Decodes bundled raster assets once and reuses them across onboarding.
/// Avoids repeated PNG decompression when scrolling player cards or opening the paywall.
enum BundledImageCache {
    private static let lock = NSLock()
    private static var storage: [String: UIImage] = [:]

    static func uiImage(named name: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = storage[name] { return cached }
        guard let image = UIImage(named: name) else { return nil }
        storage[name] = image
        return image
    }

    static func swiftUIImage(named name: String) -> Image {
        if let uiImage = uiImage(named: name) {
            return Image(uiImage: uiImage)
        }
        return Image(name)
    }

    static func warmOnboardingAssets() {
        let names = TennisPlayer.topPlayers.flatMap { player -> [String] in
            guard let imageName = player.imageName else { return [] }
            return [imageName, player.paywallImageName]
        } + GrandSlam.allCases.map(\.logoImageName) + [
            "placeholder-male",
            "placeholder-female",
            "marquee-widget-strip",
        ]
        for name in Set(names) {
            _ = uiImage(named: name)
        }
    }
}

struct CachedBundledImage: View {
    let name: String
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let uiImage = BundledImageCache.uiImage(named: name) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
    }
}
