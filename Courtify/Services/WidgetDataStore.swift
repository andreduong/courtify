import Foundation

@MainActor
final class WidgetDataStore: ObservableObject {
    static let shared = WidgetDataStore()

    @Published private(set) var payload: WidgetDataPayload?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private static let cacheKey = AppGroupConstants.Keys.widgetDataPayloadCache

    var lastUpdated: Date? { payload?.updatedAt }

    func loadCachedPayload() {
        guard payload == nil,
              let data = AppGroupConstants.userDefaults.data(forKey: Self.cacheKey) else { return }
        payload = try? JSONDecoder().decode(WidgetDataPayload.self, from: data)
    }

    func refresh() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let data = try await WidgetAPIService.fetchWidgetDataBytes()
            let decoded = try JSONDecoder().decode(WidgetDataPayload.self, from: data)
            payload = decoded
            AppGroupConstants.userDefaults.set(data, forKey: Self.cacheKey)
        } catch {
            lastError = error.localizedDescription
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

}
