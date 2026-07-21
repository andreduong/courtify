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

    /// Headshots for picker top-5 rows — apiIds from cached rankings, no lookup calls.
    /// Keeps bundled avatars for featured catalog names (preferLivePhotos: false).
    @MainActor
    static func prefetchPickerHeadshots(payload: WidgetDataPayload?) async {
        guard let payload else { return }
        let players = FavoritePlayerCatalog.topRankedPlayers(payload: payload, preferLivePhotos: false)
        for player in players {
            // Featured bundled players already have avatars — skip network.
            if player.imageName != nil { continue }

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

        if apiId == nil || (cachedEntry?.rank ?? 0) <= 0 {
            seedFromPayloadIfNeeded(player, payload: payload)
            apiId = PlayerRankCache.apiId(for: player.id) ?? apiId
        }

        let refreshedEntry = PlayerRankCache.entry(for: player.id)
        let needsRemoteLookup = refreshedEntry?.apiId == nil
            || ((refreshedEntry?.rank ?? 0) <= 0 && FavoritePlayerCatalog.payloadRankingEntry(for: player, payload: payload) == nil)

        if needsRemoteLookup {
            if let meta = await PlayerRemoteLookup.fetch(for: player, payload: payload) {
                PlayerRankCache.store(
                    rank: meta.rank,
                    apiId: meta.id,
                    name: meta.name,
                    photosVerified: refreshedEntry?.photosVerified ?? false,
                    for: player.id
                )
                apiId = meta.id
            }
        }

        let resolvedApiId = apiId ?? PlayerRankCache.apiId(for: player.id)

        if !PlayerPhotoStore.hasCachedPhotos(playerID: player.id) {
            let status = await PlayerPhotoFetcher.ensurePhotosStatus(
                for: player,
                payload: payload,
                apiId: resolvedApiId
            )
            switch status {
            case .success, .skippedBundled:
                PlayerRankCache.markPhotosVerified(for: player.id)
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
        } else {
            mediaUnavailable = false
            mediaFailureReason = .none
        }

        await ensureSeasonRecord(playerID: player.id, tour: player.tour, apiId: resolvedApiId)
    }

    /// Sparse on-demand W/L — never part of shared widget-data refresh.
    private static func ensureSeasonRecord(playerID: String, tour: TourPreference, apiId: Int?) async {
        if PlayerSeasonRecordCache.isFresh(for: playerID) { return }
        guard let apiId, apiId > 0 else { return }
        guard let record = await PlayerSeasonRecordFetcher.fetch(tour: tour, apiId: apiId) else { return }
        PlayerSeasonRecordCache.store(
            wins: record.wins,
            losses: record.losses,
            season: record.season,
            for: playerID
        )
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
