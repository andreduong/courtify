import UIKit

/// Bundled logo assets generated with the app-icon script (`courtify-logo-{preset}`).
enum CourtifyLogoRenderer {
    static func assetName(for preset: LogoBallPreset) -> String {
        "courtify-logo-\(preset.rawValue)"
    }

    static func image(for preset: LogoBallPreset) -> UIImage? {
        UIImage(named: assetName(for: preset))
            ?? UIImage(named: "courtify-logo")
    }
}
