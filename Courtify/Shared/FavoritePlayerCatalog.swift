import Foundation

enum FavoritePlayerCatalog {
    static let defaultPerTourLimit = 5

    // MARK: - Ranked lists (cached Worker payload)

    static func topRankedPlayers(
        payload: WidgetDataPayload?,
        perTourLimit: Int = defaultPerTourLimit,
        preferLivePhotos: Bool = false
    ) -> [TennisPlayer] {
        guard let payload else { return [] }
        let atp = rankedPlayers(from: payload.rankings.atp, tour: .atp, limit: perTourLimit, preferLivePhotos: preferLivePhotos)
        let wta = rankedPlayers(from: payload.rankings.wta, tour: .wta, limit: perTourLimit, preferLivePhotos: preferLivePhotos)
        return atp + wta
    }

    static func loadCachedTopPlayers(perTourLimit: Int = defaultPerTourLimit) -> [TennisPlayer] {
        topRankedPlayers(payload: WidgetPayloadReader.loadCached(), perTourLimit: perTourLimit)
    }

    /// Cached Worker top ranks when available; bundled featured catalog otherwise.
    static func pickerPlayers(
        payload: WidgetDataPayload?,
        perTourLimit: Int = defaultPerTourLimit
    ) -> [TennisPlayer] {
        let cached = topRankedPlayers(payload: payload, perTourLimit: perTourLimit, preferLivePhotos: true)
        if !cached.isEmpty { return cached }
        return TennisPlayer.topPlayers
    }

    static func rankedPlayers(
        from entries: [WidgetRankingEntry],
        tour: TourPreference,
        limit: Int,
        preferLivePhotos: Bool = false
    ) -> [TennisPlayer] {
        entries
            .filter { $0.rank != nil }
            .prefix(limit)
            .map { player(from: $0, tour: tour, preferLivePhotos: preferLivePhotos) }
    }

    static func player(
        from entry: WidgetRankingEntry,
        tour: TourPreference,
        preferLivePhotos: Bool = false
    ) -> TennisPlayer {
        let rank = entry.rank ?? 0
        let apiName = entry.player.name
        if let bundled = bundledPlayer(matching: apiName, tour: tour) {
            return TennisPlayer(
                id: bundled.id,
                name: bundled.name,
                tour: tour,
                imageName: preferLivePhotos ? nil : bundled.imageName,
                ranking: rank
            )
        }
        return TennisPlayer(
            id: TennisPlayer.makeCustomID(name: apiName, tour: tour),
            name: apiName,
            tour: tour,
            imageName: nil,
            ranking: rank
        )
    }

    // MARK: - Search (bundled catalog, zero API)

    static func searchPlayers(
        query: String,
        tourPreference: TourPreference = .both,
        limit: Int = 6
    ) -> [TennisPlayer] {
        PlayerSearchCatalog.suggestions(query: query, tourPreference: tourPreference, limit: limit)
            .map { player(from: $0) }
    }

    static func player(from entry: PlayerSearchCatalog.Entry) -> TennisPlayer {
        if let bundled = bundledPlayer(matching: entry.name, tour: entry.tour) {
            let rank = rankingInCache(name: entry.name, tour: entry.tour) ?? bundled.ranking
            return TennisPlayer(
                id: bundled.id,
                name: bundled.name,
                tour: entry.tour,
                imageName: bundled.imageName,
                ranking: rank
            )
        }
        let rank = rankingInCache(name: entry.name, tour: entry.tour)
            ?? PlayerRankCache.rank(for: TennisPlayer.makeCustomID(name: entry.name, tour: entry.tour))
            ?? 0
        return TennisPlayer(
            id: TennisPlayer.makeCustomID(name: entry.name, tour: entry.tour),
            name: entry.name,
            tour: entry.tour,
            imageName: nil,
            ranking: rank
        )
    }

    // MARK: - Resolve stored favorite ID (live rank from cache)

    static func displayRank(for id: String, payload: WidgetDataPayload?) -> Int? {
        if let payloadRank = payloadRanking(for: id, payload: payload), payloadRank > 0 {
            return payloadRank
        }
        return PlayerRankCache.rank(for: id)
    }

    static func payloadRanking(for id: String, payload: WidgetDataPayload?) -> Int? {
        guard let player = resolvedPlayerIgnoringRemoteRank(id: id, payload: payload) else { return nil }
        return rankingInCache(name: player.name, tour: player.tour, payload: payload)
    }

    static func resolvedPlayer(id: String, payload: WidgetDataPayload?) -> TennisPlayer? {
        guard let player = resolvedPlayerIgnoringRemoteRank(id: id, payload: payload) else { return nil }
        let rank = displayRank(for: id, payload: payload) ?? 0
        if rank > 0 {
            return TennisPlayer(
                id: player.id,
                name: player.name,
                tour: player.tour,
                imageName: player.imageName,
                ranking: rank
            )
        }
        return player
    }

    private static func resolvedPlayerIgnoringRemoteRank(id: String, payload: WidgetDataPayload?) -> TennisPlayer? {
        guard !id.isEmpty else { return nil }

        if let featured = TennisPlayer.player(for: id) {
            let rank = rankingInCache(player: featured, payload: payload)
            if let rank, rank > 0 {
                return TennisPlayer(
                    id: featured.id,
                    name: featured.name,
                    tour: featured.tour,
                    imageName: featured.imageName,
                    ranking: rank
                )
            }
            return featured
        }

        guard id.hasPrefix("custom:") else { return nil }
        let parts = id.split(separator: ":", maxSplits: 2)
        guard parts.count == 3,
              let name = String(parts[2]).removingPercentEncoding,
              !name.isEmpty else { return nil }
        let tour: TourPreference = parts[1] == "wta" ? .wta : .atp
        let rank = rankingInCache(name: name, tour: tour, payload: payload) ?? 0
        return TennisPlayer(
            id: id,
            name: name,
            tour: tour,
            imageName: nil,
            ranking: rank
        )
    }

    static func resolvedFavoritePlayer(payload: WidgetDataPayload? = WidgetPayloadReader.loadCached()) -> TennisPlayer? {
        let id = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoritePlayerID) ?? ""
        return resolvedPlayer(id: id, payload: payload)
    }

    static func playerForManualName(_ name: String, payload: WidgetDataPayload?) -> TennisPlayer {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let suggestion = PlayerSearchCatalog.suggestions(query: trimmed, tourPreference: .both, limit: 1).first {
            return player(from: suggestion)
        }
        let canonical = canonicalNameInCache(for: trimmed, payload: payload) ?? trimmed
        if let bundled = bundledPlayer(matching: canonical, tour: .atp) {
            return resolvedPlayer(id: bundled.id, payload: payload) ?? bundled
        }
        if let bundled = bundledPlayer(matching: canonical, tour: .wta) {
            return resolvedPlayer(id: bundled.id, payload: payload) ?? bundled
        }
        let atpRank = rankingInCache(name: canonical, tour: .atp, payload: payload)
        let wtaRank = rankingInCache(name: canonical, tour: .wta, payload: payload)
        let tour: TourPreference = wtaRank != nil && atpRank == nil ? .wta : .atp
        let customID = TennisPlayer.makeCustomID(name: canonical, tour: tour)
        let rank = tour == .wta
            ? (wtaRank ?? PlayerRankCache.rank(for: customID) ?? 0)
            : (atpRank ?? PlayerRankCache.rank(for: customID) ?? 0)
        return TennisPlayer(
            id: TennisPlayer.makeCustomID(name: canonical, tour: tour),
            name: canonical,
            tour: tour,
            imageName: nil,
            ranking: rank
        )
    }

    private static func canonicalNameInCache(for name: String, payload: WidgetDataPayload?) -> String? {
        guard let payload else { return nil }
        for tour in [TourPreference.atp, .wta] {
            let entries = tour == .wta ? payload.rankings.wta : payload.rankings.atp
            let foldedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            let lastName = foldedName.split(separator: " ").last.map(String.init)
            if let match = entries.first(where: {
                let entryName = $0.player.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
                let entryLast = entryName.split(separator: " ").last.map(String.init)
                return entryName == foldedName
                    || (lastName != nil && entryLast == lastName)
                    || (lastName != nil && entryLast != nil && levenshtein(entryLast!, lastName!) <= 1)
            }) {
                return match.player.name
            }
        }
        return nil
    }

    // MARK: - App Entity helpers (widget configuration)

    struct PlayerEntitySnapshot: Identifiable, Hashable {
        let id: String
        let name: String
        let tourRaw: String
        let rank: Int
    }

    static func entitySnapshots(perTourLimit: Int = defaultPerTourLimit) -> [PlayerEntitySnapshot] {
        loadCachedTopPlayers(perTourLimit: perTourLimit).map(entitySnapshot(from:))
    }

    static func entitySnapshot(for id: String) -> PlayerEntitySnapshot? {
        guard let player = resolvedPlayer(id: id, payload: WidgetPayloadReader.loadCached()) else { return nil }
        return entitySnapshot(from: player)
    }

    static func searchEntitySnapshots(matching query: String, limit: Int = 8) -> [PlayerEntitySnapshot] {
        searchPlayers(query: query, limit: limit).map(entitySnapshot(from:))
    }

    static func entitySnapshot(from player: TennisPlayer) -> PlayerEntitySnapshot {
        PlayerEntitySnapshot(
            id: player.id,
            name: player.name,
            tourRaw: player.tour.rawValue,
            rank: player.ranking
        )
    }

    // MARK: - Bundled name matching

    static func bundledPlayer(matching name: String, tour: TourPreference) -> TennisPlayer? {
        func fold(_ string: String) -> String {
            string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        }
        let parts = fold(name).split(separator: " ")
        guard let lastName = parts.last, let firstInitial = parts.first?.first else { return nil }
        return TennisPlayer.topPlayers.first { candidate in
            guard candidate.tour == tour else { return false }
            let candidateParts = fold(candidate.name).split(separator: " ")
            return candidateParts.last == lastName && candidateParts.first?.first == firstInitial
        }
    }

    private static func rankingInCache(player: TennisPlayer, payload: WidgetDataPayload?) -> Int? {
        rankingInCache(name: player.name, tour: player.tour, payload: payload)
    }

    private static func rankingInCache(
        name: String,
        tour: TourPreference,
        payload: WidgetDataPayload? = WidgetPayloadReader.loadCached()
    ) -> Int? {
        payloadRankingEntry(name: name, tour: tour, payload: payload)?.rank
    }

    /// Top-20 payload row for a player name (seeds apiId without an extra lookup call).
    static func payloadRankingEntry(
        for player: TennisPlayer,
        payload: WidgetDataPayload?
    ) -> WidgetRankingEntry? {
        payloadRankingEntry(name: player.name, tour: player.tour, payload: payload)
    }

    static func payloadRankingEntry(
        name: String,
        tour: TourPreference,
        payload: WidgetDataPayload?
    ) -> WidgetRankingEntry? {
        guard let payload else { return nil }
        let entries = tour == .wta ? payload.rankings.wta : payload.rankings.atp
        let foldedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        let lastName = foldedName.split(separator: " ").last.map(String.init)

        return entries.first { entry in
            let entryName = entry.player.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            let entryLast = entryName.split(separator: " ").last.map(String.init)
            return entryName == foldedName
                || (lastName != nil && entryLast == lastName)
                || (lastName != nil && entryLast != nil && levenshtein(entryLast!, lastName!) <= 1)
        }
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 0 }
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0 ... rhs.count)
        for (i, leftChar) in lhs.enumerated() {
            var current = [i + 1]
            for (j, rightChar) in rhs.enumerated() {
                let insertions = previous[j + 1] + 1
                let deletions = current[j] + 1
                let substitutions = previous[j] + (leftChar == rightChar ? 0 : 1)
                current.append(min(insertions, deletions, substitutions))
            }
            previous = current
        }
        return previous.last ?? max(lhs.count, rhs.count)
    }
}
