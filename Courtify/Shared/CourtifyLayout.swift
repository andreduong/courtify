import UIKit

enum CourtifyLayout {
    /// Top safe inset from the key window. Use when child views call `ignoresSafeArea()`
    /// and SwiftUI's environment insets collapse to zero for overlays.
    static var topSafeInset: CGFloat {
        guard let window = activeWindow else { return 59 }
        return max(window.safeAreaInsets.top, 20)
    }

    private static var activeWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first
    }
}
