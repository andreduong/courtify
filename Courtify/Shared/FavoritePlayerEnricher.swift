import Foundation

/// One-time rank + photo fetch for favorites without bundled hero assets (main app only).
enum FavoritePlayerEnricher {
    /// Set when a custom favorite’s photo fetch fails (quota / upstream). Cleared on success.
    static let mediaUnavailableKey = "favoritePlayerMediaUnavailable"
    private static let mediaAlertPresentedKey = "favoritePlayerMediaAlertPresentedID"

    @MainActor
    static var mediaUnavailable: Bool {
        get { AppGroupConstants.userDefaults.bool(forKey: mediaUnavailableKey) }
        set { AppGroupConstants.userDefaults.set(newValue, forKey: mediaUnavailableKey) }
    }

    @MainActor
    static func shouldPresentMediaUnavailableAlert(for playerID: String) -> Bool {
        guard !playerID.isEmpty else { return false }
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

    @MainActor
    static func ensureLoaded(playerID: String, payload: WidgetDataPayload?) async {
        guard let player = FavoritePlayerCatalog.resolvedPlayer(id: playerID, payload: payload),
              player.imageName == nil else {
            mediaUnavailable = false
            return
        }

        let hadRank = (FavoritePlayerCatalog.displayRank(for: playerID, payload: payload) ?? 0) > 0
        let hadPhotos = PlayerPhotoStore.hasCachedPhotos(playerID: playerID)

        await enrich(player, payload: payload, clearExisting: false)

        let hasRank = (FavoritePlayerCatalog.displayRank(for: playerID, payload: payload) ?? 0) > 0
        let hasPhotos = PlayerPhotoStore.hasCachedPhotos(playerID: playerID)
        mediaUnavailable = !hasPhotos

        guard (!hadRank && hasRank) || (!hadPhotos && hasPhotos) else { return }

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
            return
        }

        if clearExisting {
            PlayerPhotoStore.clearCachedPhotos(for: player.id)
            PlayerRankCache.remove(for: player.id)
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

        if !PlayerPhotoStore.hasCachedPhotos(playerID: player.id) {
            let photosSaved = await PlayerPhotoFetcher.ensurePhotos(
                for: player,
                payload: payload,
                apiId: apiId ?? PlayerRankCache.apiId(for: player.id)
            )
            if photosSaved {
                PlayerRankCache.markPhotosVerified(for: player.id)
                mediaUnavailable = false
            } else {
                mediaUnavailable = true
            }
        } else {
            mediaUnavailable = false
        }
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
