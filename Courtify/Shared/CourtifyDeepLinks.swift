import Foundation

enum CourtifyDeepLinks {
    static let paywallURL = URL(string: "courtify://paywall")!

    static func isPaywall(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "courtify" else { return false }
        if url.host?.lowercased() == "paywall" { return true }
        return url.path == "/paywall"
    }
}
