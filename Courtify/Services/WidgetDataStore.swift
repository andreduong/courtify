import Foundation

@MainActor
final class WidgetDataStore: ObservableObject {
    static let shared = WidgetDataStore()

    @Published private(set) var payload: WidgetDataPayload?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private static let cacheKey = AppGroupConstants.Keys.widgetDataPayloadCache
    private var refreshTask: Task<Void, Never>?

    var lastUpdated: Date? { payload?.updatedAt }

    func loadCachedPayload() {
        guard payload == nil,
              let data = AppGroupConstants.userDefaults.data(forKey: Self.cacheKey) else { return }
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
                lastError = userFacingMessage(for: error)
            }
        }

        refreshTask = task
        await task.value
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

        await refresh()
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
            case .httpStatus(let code): return "Server error (\(code)). Try again shortly."
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
