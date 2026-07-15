import Foundation

enum WidgetPayloadReader {
    static func loadCached() -> WidgetDataPayload? {
        guard let data = AppGroupConstants.userDefaults.data(forKey: AppGroupConstants.Keys.widgetDataPayloadCache) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetDataPayload.self, from: data)
    }

    /// Widget extension reads app-group cache only — never hits the Worker.
    static func loadPayload() -> WidgetDataPayload? {
        loadCached()
    }

    static func preferredTour() -> TourPreference {
        let raw = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.tourPreference)
            ?? TourPreference.atp.rawValue
        let tour = TourPreference(rawValue: raw) ?? .atp
        return tour == .both ? .atp : tour
    }

    static func favoritePlayer() -> TennisPlayer? {
        let id = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoritePlayerID) ?? ""
        guard !id.isEmpty else { return nil }
        return TennisPlayer.player(for: id)
    }

    static func nextRefreshDate(after date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .minute, value: 30, to: date) ?? date.addingTimeInterval(1800)
    }
}
