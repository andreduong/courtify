import Foundation

/// On-demand season W/L for custom favorites (Worker KV caches 24h).
enum PlayerSeasonRecordFetcher {
    struct Record {
        let wins: Int
        let losses: Int
        let season: Int
    }

    static func fetch(tour: TourPreference, apiId: Int) async -> Record? {
        guard apiId > 0 else { return nil }

        var components = URLComponents(string: WidgetAPIService.playerSeasonRecordURL.absoluteString)
        components?.queryItems = [
            URLQueryItem(name: "tour", value: tour == .wta ? "wta" : "atp"),
            URLQueryItem(name: "apiId", value: String(apiId)),
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard decoded.wins >= 0, decoded.losses >= 0 else { return nil }
            return Record(
                wins: decoded.wins,
                losses: decoded.losses,
                season: decoded.season ?? Calendar.current.component(.year, from: Date())
            )
        } catch {
            return nil
        }
    }

    private struct ResponseBody: Decodable {
        let wins: Int
        let losses: Int
        let season: Int?
    }
}
