import Foundation

enum WidgetAPIService {
    /// Set this to your deployed Worker URL (`wrangler deploy` → `https://<name>.<subdomain>.workers.dev/api/widget-data`).
    static let widgetDataURL = URL(string: "https://courtify-tennis-worker.courtify.workers.dev/api/widget-data")!

    static func fetchWidgetData() async throws -> WidgetDataPayload {
        if AppGroupConstants.useMockWidgetData {
            return WidgetMockData.sample
        }

        var request = URLRequest(url: widgetDataURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 25

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WidgetAPIError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw WidgetAPIError.httpStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WidgetDataPayload.self, from: data)
    }
}

enum WidgetAPIError: Error {
    case invalidResponse
    case httpStatus(Int)
}
