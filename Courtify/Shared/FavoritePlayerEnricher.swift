import Foundation

/// One-time rank + photo fetch for favorites without bundled hero assets (main app only).
enum FavoritePlayerEnricher {
    /// Set when a custom favorite’s photo fetch fails. Cleared on success.
    static let mediaUnavailableKey = "favoritePlayerMediaUnavailable"
    static let mediaFailureReasonKey = "favoritePlayerMediaFailureReason"
    private static let mediaAlertPresentedKey = "favoritePlayerMediaAlertPresentedID"

    enum MediaFailureReason: String {
        case none
        case quota
        case notFound
        case upstream
        case failed
    }

    @MainActor
    static var mediaUnavailable: Bool {
        get { AppGroupConstants.userDefaults.bool(forKey: mediaUnavailableKey) }
        set { AppGroupConstants.userDefaults.set(newValue, forKey: mediaUnavailableKey) }
    }

    @MainActor
    static var mediaFailureReason: MediaFailureReason {
        get {
            let raw = AppGroupConstants.userDefaults.string(forKey: mediaFailureReasonKey) ?? ""
            return MediaFailureReason(rawValue: raw) ?? .none
        }
        set {
            if newValue == .none {
                AppGroupConstants.userDefaults.removeObject(forKey: mediaFailureReasonKey)
            } else {
                AppGroupConstants.userDefaults.set(newValue.rawValue, forKey: mediaFailureReasonKey)
            }
        }
    }

    @MainActor
    static func shouldPresentMediaUnavailableAlert(for playerID: String) -> Bool {
        guard !playerID.isEmpty else { return false }
        // Only alert for true quota — inactive/not-found fails silently with silhouette.
        guard mediaFailureReason == .quota else { return false }
        let shown = AppGroupConstants.userDefaults.string(forKey: mediaAlertPresentedKey)
        return shown != playerID
    }

    @MainActor
    static func markMediaUnavailableAlertPresented(for playerID: String) {
        AppGroupConstants.userDefaults.set(playerID, forKey: mediaAlertPresentedKey)
    }

    @MainActor
    static func clearMediaUnavailableAlertMarker() {
        AppGroupConstants.userDefaults.removeObject(forKey: mediaAlertPresentedKey)
    }

    /// Headshots for picker top-10 rows — apiIds from cached rankings, no lookup calls.
    /// Skips anyone with a bundled hero cutout (featured or name-slug catalog).
    @MainActor
    static func prefetchPickerHeadshots(payload: WidgetDataPayload?) async {
        guard let payload else { return }
        let players = FavoritePlayerCatalog.topRankedPlayers(payload: payload, preferLivePhotos: false)
        for player in players {
            // Bundled hero / avatar already covers the circular row — skip network.
            if player.bundledHeroCutoutName != nil || player.imageName != nil { continue }

            guard let entry = FavoritePlayerCatalog.payloadRankingEntry(for: player, payload: payload),
                  let apiId = entry.player.id, apiId > 0 else { continue }

            if PlayerRankCache.apiId(for: player.id) == nil {
                PlayerRankCache.store(
                    rank: entry.rank ?? player.ranking,
                    apiId: apiId,
                    name: player.name,
                    photosVerified: false,
                    for: player.id
                )
            }

            guard !PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .head) else { continue }
            if await PlayerPhotoFetcher.ensureHeadPhoto(for: player, payload: payload, apiId: apiId) {
                PlayerRankCache.markPhotosVerified(for: player.id)
            }
        }
    }

    @MainActor
    static func ensureLoaded(playerID: String, payload: WidgetDataPayload?) async {
        guard let player = FavoritePlayerCatalog.resolvedPlayer(id: playerID, payload: payload),
              player.imageName == nil else {
            mediaUnavailable = false
            mediaFailureReason = .none
            return
        }

        let hadRank = (FavoritePlayerCatalog.displayRank(for: playerID, payload: payload) ?? 0) > 0
        let hadPhotos = PlayerPhotoStore.hasCachedPhotos(playerID: playerID)
        let hadSeason = PlayerSeasonRecordCache.record(for: playerID) != nil

        await enrich(player, payload: payload, clearExisting: false)

        let hasRank = (FavoritePlayerCatalog.displayRank(for: playerID, payload: payload) ?? 0) > 0
        let hasPhotos = PlayerPhotoStore.hasCachedPhotos(playerID: playerID)
        let hasSeason = PlayerSeasonRecordCache.record(for: playerID) != nil
        mediaUnavailable = !hasPhotos

        guard (!hadRank && hasRank) || (!hadPhotos && hasPhotos) || (!hadSeason && hasSeason) else { return }

        WidgetTimelineRefresher.reloadAll()
        NotificationCenter.default.post(name: AppGroupConstants.favoritePlayerDidChange, object: nil)
    }

    @MainActor
    static func enrich(
        _ player: TennisPlayer,
        payload: WidgetDataPayload?,
        clearExisting: Bool
    ) async {
        guard player.imageName == nil else {
            mediaUnavailable = false
            mediaFailureReason = .none
            return
        }

        if clearExisting {
            PlayerPhotoStore.clearCachedPhotos(for: player.id)
            PlayerRankCache.remove(for: player.id)
            PlayerSeasonRecordCache.remove(for: player.id)
            clearMediaUnavailableAlertMarker()
        }

        let cachedEntry = PlayerRankCache.entry(for: player.id)
        var apiId = cachedEntry?.apiId
        var lookupWasNotFound = false

        if apiId == nil || (cachedEntry?.rank ?? 0) <= 0 {
            seedFromPayloadIfNeeded(player, payload: payload)
            apiId = PlayerRankCache.apiId(for: player.id) ?? apiId
        }

        // Retired legends never have a live rank or current-season record —
        // bundled `careerRecord` covers every surface, so skip the lookup and
        // season-record calls entirely (they would 404 and burn quota).
        let isLegend = player.isRetiredLegend

        let refreshedEntry = PlayerRankCache.entry(for: player.id)
        let needsRemoteLookup = !isLegend && (refreshedEntry?.apiId == nil
            || ((refreshedEntry?.rank ?? 0) <= 0 && FavoritePlayerCatalog.payloadRankingEntry(for: player, payload: payload) == nil))

        if needsRemoteLookup {
            switch await PlayerRemoteLookup.fetchStatus(for: player, payload: payload) {
            case .found(let meta):
                PlayerRankCache.store(
                    rank: meta.rank,
                    apiId: meta.id,
                    name: meta.name,
                    photosVerified: refreshedEntry?.photosVerified ?? false,
                    for: player.id
                )
                apiId = meta.id
            case .notFound:
                lookupWasNotFound = true
            case .quota, .failed, .skipped:
                break
            }
        }

        let resolvedApiId = apiId ?? PlayerRankCache.apiId(for: player.id)

        // Photo + season W/L run concurrently — never gate season on photo success/failure.
        // (nil apiId for legends short-circuits the season fetch.)
        async let seasonStored = ensureSeasonRecord(
            playerID: player.id,
            tour: player.tour,
            apiId: isLegend ? nil : resolvedApiId
        )

        if PlayerPhotoStore.hasCachedPhotos(playerID: player.id) {
            mediaUnavailable = false
            mediaFailureReason = .none
        } else {
            let status = await PlayerPhotoFetcher.ensurePhotosStatus(
                for: player,
                payload: payload,
                apiId: resolvedApiId
            )
            applyPhotoStatus(status, lookupWasNotFound: lookupWasNotFound, playerID: player.id)
        }

        _ = await seasonStored
    }

    /// Sparse on-demand heal for the active custom favorite — used by pull-to-refresh
    /// when the season W/L or the rank is missing. Never part of shared widget-data cost.
    @MainActor
    @discardableResult
    static func healSeasonRecordIfNeeded(playerID: String, payload: WidgetDataPayload?) async -> Bool {
        guard playerID.hasPrefix("custom:") else { return false }
        let needsSeason = PlayerSeasonRecordCache.record(for: playerID) == nil
        let needsRank = (FavoritePlayerCatalog.displayRank(for: playerID, payload: payload) ?? 0) <= 0
        guard needsSeason || needsRank else { return false }
        guard let player = FavoritePlayerCatalog.resolvedPlayer(id: playerID, payload: payload),
              player.imageName == nil else { return false }
        // Legends always look "missing rank + season" — without this guard every
        // pull-to-refresh would re-fire a doomed lookup for Federer-type picks.
        guard !player.isRetiredLegend else { return false }

        var apiId = PlayerRankCache.apiId(for: playerID)
        if apiId == nil || (apiId ?? 0) <= 0 {
            seedFromPayloadIfNeeded(player, payload: payload)
            apiId = PlayerRankCache.apiId(for: playerID)
        }
        var healedRank = false
        if apiId == nil || (apiId ?? 0) <= 0 || needsRank {
            // fetchStatus retries the Worker (with apiId hint) when the cached rank is <= 0.
            if let meta = await PlayerRemoteLookup.fetch(for: player, payload: payload) {
                let previousRank = PlayerRankCache.rank(for: playerID) ?? 0
                PlayerRankCache.store(
                    rank: meta.rank,
                    apiId: meta.id,
                    name: meta.name,
                    photosVerified: PlayerRankCache.entry(for: playerID)?.photosVerified ?? false,
                    for: playerID
                )
                apiId = meta.id
                healedRank = meta.rank > 0 && previousRank <= 0
            }
        }

        let storedSeason = needsSeason
            ? await ensureSeasonRecord(playerID: playerID, tour: player.tour, apiId: apiId)
            : false
        guard storedSeason || healedRank else { return false }
        WidgetTimelineRefresher.reloadAll()
        NotificationCenter.default.post(name: AppGroupConstants.favoritePlayerDidChange, object: nil)
        return true
    }

    @MainActor
    private static func applyPhotoStatus(
        _ status: PlayerPhotoFetchStatus,
        lookupWasNotFound: Bool,
        playerID: String
    ) {
        // Inactive/unranked (lookup 404): never surface "daily API limit" even if the
        // photo proxy returns 429 (stale quota gate + CDN 403 normalized poorly).
        let effective: PlayerPhotoFetchStatus = {
            if lookupWasNotFound {
                switch status {
                case .success, .skippedBundled:
                    return status
                default:
                    return .notFound
                }
            }
            return status
        }()

        switch effective {
        case .success, .skippedBundled:
            PlayerRankCache.markPhotosVerified(for: playerID)
            mediaUnavailable = false
            mediaFailureReason = .none
            WidgetTimelineRefresher.reloadAll()
            NotificationCenter.default.post(name: AppGroupConstants.favoritePlayerDidChange, object: nil)
        case .quota:
            mediaUnavailable = true
            mediaFailureReason = .quota
        case .notFound:
            mediaUnavailable = true
            mediaFailureReason = .notFound
        case .upstream:
            mediaUnavailable = true
            mediaFailureReason = .upstream
        case .failed:
            mediaUnavailable = true
            mediaFailureReason = .failed
        }
    }

    /// Sparse on-demand W/L — never part of shared widget-data refresh.
    @discardableResult
    private static func ensureSeasonRecord(playerID: String, tour: TourPreference, apiId: Int?) async -> Bool {
        if PlayerSeasonRecordCache.isFresh(for: playerID) { return false }
        guard let apiId, apiId > 0 else { return false }
        guard let record = await PlayerSeasonRecordFetcher.fetch(tour: tour, apiId: apiId) else { return false }
        PlayerSeasonRecordCache.store(
            wins: record.wins,
            losses: record.losses,
            season: record.season,
            for: playerID
        )
        return true
    }

    private static func seedFromPayloadIfNeeded(
        _ player: TennisPlayer,
        payload: WidgetDataPayload?
    ) {
        guard let entry = FavoritePlayerCatalog.payloadRankingEntry(for: player, payload: payload),
              let apiId = entry.player.id, apiId > 0 else { return }

        let existing = PlayerRankCache.entry(for: player.id)
        let rank = entry.rank ?? existing?.rank ?? 0
        guard existing?.apiId == nil || (existing?.rank ?? 0) <= 0 else { return }

        PlayerRankCache.store(
            rank: rank,
            apiId: apiId,
            name: entry.player.name,
            photosVerified: existing?.photosVerified ?? false,
            for: player.id
        )
    }
}
