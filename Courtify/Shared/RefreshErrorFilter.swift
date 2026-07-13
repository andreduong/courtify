import Foundation

enum RefreshErrorFilter {
    /// Pull-to-refresh dismissals surface as `CancellationError` / URLError.cancelled — not user-facing failures.
    static func isBenignCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return true }
        return error.localizedDescription.lowercased() == "cancelled"
    }
}
