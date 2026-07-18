import Foundation

enum CourtifyDeepLinks {
    static let paywallURL = URL(string: "courtify://paywall")!

    /// Public App Store listing — update to `https://apps.apple.com/app/idXXXXXXXX` once assigned.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/courtify")!

    static func isPaywall(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "courtify" else { return false }
        if url.host?.lowercased() == "paywall" { return true }
        return url.path == "/paywall"
    }
}
