import UIKit

enum AppIconManager {
    /// Alternate icon asset name, or `nil` for the primary AppIcon set.
    static func alternateIconName(for preset: LogoBallPreset) -> String? {
        switch preset {
        case .courtify: nil
        case .hardcourt: "AppIcon-Hardcourt"
        case .clay: "AppIcon-Clay"
        case .grass: "AppIcon-Grass"
        case .berry: "AppIcon-Berry"
        case .white: "AppIcon-White"
        case .optic: "AppIcon-Optic"
        }
    }

    /// Sync the SpringBoard icon to the stored logo-ball preset.
    @MainActor
    static func applyStoredLogoBall() {
        applyLogoBall(AppAppearanceStore.shared.logoBall)
    }

    static func applyLogoBall(_ preset: LogoBallPreset) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let target = alternateIconName(for: preset)
        guard UIApplication.shared.alternateIconName != target else { return }

        UIApplication.shared.setAlternateIconName(target) { error in
            #if DEBUG
            if let error {
                print("AppIconManager: failed to set icon — \(error.localizedDescription)")
            }
            #endif
        }
    }
}
