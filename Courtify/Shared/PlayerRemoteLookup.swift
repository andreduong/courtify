import Foundation

/// On-demand player metadata for favorites outside the cached top-20 rankings.
/// One Worker call per uncached name (Worker KV caches for 30 days).
enum PlayerRemoteLookup {
    struct Meta: Equatable {
        let id: Int
        let rank: Int
        let name: String
    }

    enum Status: Equatable {
        case found(Meta)
        /// Outside rankings top-100 / inactive — not a quota problem.
        case notFound
        case quota
        case failed
        /// Already have cache or payload match; no network needed.
        case skipped
    }

    /// Fetches rank + API id when the player is not in the local top-20 cache.
    static func fetch(for player: TennisPlayer, payload: WidgetDataPayload?) async -> Meta? {
        switch await fetchStatus(for: player, payload: payload) {
        case .found(let meta): return meta
        default: return nil
        }
    }

    static func fetchStatus(for player: TennisPlayer, payload: WidgetDataPayload?) async -> Status {
        if player.imageName != nil {
            return .skipped
        }

        if let cached = PlayerRankCache.entry(for: player.id),
           let apiId = cached.apiId, apiId > 0 {
            return .found(Meta(id: apiId, rank: cached.rank, name: cached.name ?? player.name))
        }

        if rankingEntry(matching: player.name, tour: player.tour, payload: payload) != nil {
            return .skipped
        }

        let remote = await fetchFromWorkerStatus(for: player)
        switch remote {
        case .found, .quota, .failed, .notFound:
            return remote
        case .skipped:
            break
        }

        if let bundledId = PlayerSearchCatalog.bundledApiId(for: player.name, tour: player.tour), bundledId > 0 {
            return .found(Meta(id: bundledId, rank: 0, name: player.name))
        }

        return .notFound
    }

    private static func fetchFromWorkerStatus(for player: TennisPlayer) async -> Status {
        var components = URLComponents(string: WidgetAPIService.playerLookupURL.absoluteString)
        components?.queryItems = [
            URLQueryItem(name: "tour", value: player.tour == .wta ? "wta" : "atp"),
            URLQueryItem(name: "name", value: player.name),
        ]
        guard let url = components?.url else { return .failed }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }

            switch http.statusCode {
            case 200 ... 299:
                let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
                guard decoded.id > 0 else { return .notFound }
                return .found(Meta(
                    id: decoded.id,
                    rank: decoded.rank ?? 0,
                    name: decoded.name ?? player.name
                ))
            case 404, 400:
                return .notFound
            case 429, 503:
                return .quota
            default:
                return .failed
            }
        } catch {
            return .failed
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
