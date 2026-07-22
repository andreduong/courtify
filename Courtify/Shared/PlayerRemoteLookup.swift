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

        let cached = PlayerRankCache.entry(for: player.id)

        // Fully-resolved cache (id + real rank) needs no network. A cached apiId with
        // rank <= 0 (e.g. outside the top 100 at first pick) still retries the Worker so
        // the profile fallback can fill the live rank in.
        if let cached, let apiId = cached.apiId, apiId > 0, cached.rank > 0 {
            return .found(Meta(id: apiId, rank: cached.rank, name: cached.name ?? player.name))
        }

        if rankingEntry(matching: player.name, tour: player.tour, payload: payload) != nil {
            return .skipped
        }

        // Verified apiId hint lets the Worker resolve players ranked outside the
        // top 100 via the profile endpoint (rankings scan alone misses them).
        let apiIdHint = cached?.apiId
            ?? PlayerSearchCatalog.bundledApiId(for: player.name, tour: player.tour)

        let remote = await fetchFromWorkerStatus(for: player, apiIdHint: apiIdHint)
        if case .found = remote {
            return remote
        }

        // Worker miss/failure: a known apiId (cached or bundled-verified) still enables
        // photos + season W/L even when the live rank is unknown.
        if let cached, let apiId = cached.apiId, apiId > 0 {
            return .found(Meta(id: apiId, rank: cached.rank, name: cached.name ?? player.name))
        }
        if let bundledId = apiIdHint, bundledId > 0 {
            return .found(Meta(id: bundledId, rank: 0, name: player.name))
        }

        return remote
    }

    private static func fetchFromWorkerStatus(for player: TennisPlayer, apiIdHint: Int?) async -> Status {
        var components = URLComponents(string: WidgetAPIService.playerLookupURL.absoluteString)
        var queryItems = [
            URLQueryItem(name: "tour", value: player.tour == .wta ? "wta" : "atp"),
            URLQueryItem(name: "name", value: player.name),
        ]
        if let apiIdHint, apiIdHint > 0 {
            queryItems.append(URLQueryItem(name: "apiId", value: String(apiIdHint)))
        }
        components?.queryItems = queryItems
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
