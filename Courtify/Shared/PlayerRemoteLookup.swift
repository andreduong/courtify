import Foundation

/// On-demand player metadata for favorites outside the cached top-20 rankings.
/// One Worker call per uncached name (Worker KV caches for 30 days).
enum PlayerRemoteLookup {
    struct Meta {
        let id: Int
        let rank: Int
        let name: String
    }

    /// Fetches rank + API id when the player is not in the local top-20 cache.
    static func fetch(for player: TennisPlayer, payload: WidgetDataPayload?) async -> Meta? {
        if player.imageName != nil {
            return nil
        }

        if let cached = PlayerRankCache.entry(for: player.id),
           let apiId = cached.apiId, cached.rank > 0 {
            return Meta(id: apiId, rank: cached.rank, name: cached.name ?? player.name)
        }

        if rankingEntry(matching: player.name, tour: player.tour, payload: payload) != nil {
            return nil
        }

        var components = URLComponents(string: WidgetAPIService.playerLookupURL.absoluteString)
        components?.queryItems = [
            URLQueryItem(name: "tour", value: player.tour == .wta ? "wta" : "atp"),
            URLQueryItem(name: "name", value: player.name),
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let rank = decoded.rank, rank > 0, decoded.id > 0 else { return nil }
            return Meta(id: decoded.id, rank: rank, name: decoded.name ?? player.name)
        } catch {
            return nil
        }
    }

    private struct LookupResponse: Decodable {
        let id: Int
        let rank: Int?
        let name: String?
    }

    private static func rankingEntry(
        matching name: String,
        tour: TourPreference,
        payload: WidgetDataPayload?
    ) -> WidgetRankingEntry? {
        guard let payload else { return nil }
        let entries = tour == .wta ? payload.rankings.wta : payload.rankings.atp
        let foldedName = folded(name)
        let lastName = foldedName.split(separator: " ").last.map(String.init)

        return entries.first { entry in
            let entryName = folded(entry.player.name)
            let entryLast = entryName.split(separator: " ").last.map(String.init)
            return entryName == foldedName
                || (lastName != nil && entryLast == lastName)
        }
    }

    private static func folded(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
    }
}
