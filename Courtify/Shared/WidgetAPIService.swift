import Foundation

enum WidgetAPIService {
    /// Set this to your deployed Worker URL (`wrangler deploy` → `https://<name>.<subdomain>.workers.dev/api/widget-data`).
    static let widgetDataURL = URL(string: "https://courtify-tennis-worker.courtify.workers.dev/api/widget-data")!

    static func fetchWidgetData() async throws -> WidgetDataPayload {
        let data = try await fetchWidgetDataBytes()
        return try JSONDecoder().decode(WidgetDataPayload.self, from: data)
    }

    static func fetchWidgetDataBytes() async throws -> Data {
        if AppGroupConstants.useMockWidgetData {
            return Data(WidgetMockData.sampleJSON.utf8)
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

        return data
    }
}

enum WidgetAPIError: Error {
    case invalidResponse
    case httpStatus(Int)
}
