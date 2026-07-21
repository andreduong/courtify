import Foundation

@MainActor
final class WidgetDataStore: ObservableObject {
    static let shared = WidgetDataStore()

    @Published private(set) var payload: WidgetDataPayload?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var quotaExceededOnLastRefresh = false

    private static let cacheKey = AppGroupConstants.Keys.widgetDataPayloadCache
    private var refreshTask: Task<Void, Never>?

    var lastUpdated: Date? { payload?.updatedAt }

    var hasCachedPayload: Bool {
        payload != nil || AppGroupConstants.userDefaults.data(forKey: Self.cacheKey) != nil
    }

    func loadCachedPayload() {
        guard let data = AppGroupConstants.userDefaults.data(forKey: Self.cacheKey) else { return }
        payload = try? JSONDecoder().decode(WidgetDataPayload.self, from: data)
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            lastError = nil
            quotaExceededOnLastRefresh = false
            defer {
                isLoading = false
                self.refreshTask = nil
            }

            do {
                let data = try await WidgetAPIService.fetchWidgetDataBytes()
                try Task.checkCancellation()
                let decoded = try JSONDecoder().decode(WidgetDataPayload.self, from: data)
                payload = decoded
                AppGroupConstants.userDefaults.set(data, forKey: Self.cacheKey)
            } catch {
                guard !RefreshErrorFilter.isBenignCancellation(error) else { return }
                if let apiError = error as? WidgetAPIError, apiError.isQuotaExceeded {
                    quotaExceededOnLastRefresh = true
                    loadCachedPayload()
                } else {
                    lastError = userFacingMessage(for: error)
                    loadCachedPayload()
                }
            }

            // Targeted heal only — never mass-fetch season W/L inside widget-data.
            // If the custom favorite is missing a season record (e.g. photo failed first
            // on pick), recover it on pull-to-refresh without expanding shared refresh.
            scheduleFavoriteSeasonRecordHeal()
        }

        refreshTask = task
        await task.value
    }

    /// Fires a single-player season W/L fetch when the active favorite is `custom:` and
    /// `PlayerSeasonRecordCache` has nothing stored. Does not touch shared widget-data cost.
    private func scheduleFavoriteSeasonRecordHeal() {
        let playerID = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoritePlayerID) ?? ""
        guard playerID.hasPrefix("custom:") else { return }
        guard PlayerSeasonRecordCache.record(for: playerID) == nil else { return }
        let snapshot = payload
        Task { @MainActor in
            _ = await FavoritePlayerEnricher.healSeasonRecordIfNeeded(
                playerID: playerID,
                payload: snapshot
            )
        }
    }

    /// Loads cached rankings when present; otherwise fetches once from the Worker.
    /// Safe to call from pickers and onboarding — concurrent callers coalesce via `refresh()`.
    func ensureRankingsLoaded() async {
        loadCachedPayload()
        guard payload == nil else { return }
        await refresh()
    }

    /// One-time fetch so onboarding can show real rankings on the very first
    /// app open (API cost: a single Worker request, ever). Skipped when a
    /// cached payload already exists; the success flag prevents refetching if
    /// the user re-runs onboarding after the cache was cleared.
    func refreshOnceForOnboarding() async {
        loadCachedPayload()
        guard payload == nil else { return }

        let flagKey = AppGroupConstants.Keys.didFetchOnboardingRankings
        guard !AppGroupConstants.userDefaults.bool(forKey: flagKey) else { return }

        await ensureRankingsLoaded()
        if payload != nil {
            AppGroupConstants.userDefaults.set(true, forKey: flagKey)
        }
    }

    func rankings(for tour: TourPreference) -> [WidgetRankingEntry] {
        guard let payload else { return [] }
        switch tour {
        case .atp: return payload.rankings.atp
        case .wta: return payload.rankings.wta
        case .both: return payload.rankings.atp
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let apiError = error as? WidgetAPIError {
            switch apiError {
            case .invalidResponse: return "Could not reach Courtify servers."
            case .httpStatus(let code):
                if apiError.isQuotaExceeded {
                    return "Tennis API quota reached. Showing your last saved rankings."
                }
                return "Server error (\(code)). Try again shortly."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection."
            case .timedOut:
                return "Request timed out. Pull to try again."
            default:
                break
            }
        }
        return "Could not load tennis data. Pull to try again."
    }
}
