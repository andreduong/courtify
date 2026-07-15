import Foundation

/// Rich placeholder data for the system widget gallery and Xcode previews.
enum WidgetPreviewSamples {
    static var payload: WidgetDataPayload { WidgetMockData.sample }

    static var favoritePlayer: TennisPlayer {
        TennisPlayer.player(for: "alcaraz") ?? TennisPlayer.topPlayers[2]
    }

    static func rankings(for tour: TourPreference) -> [WidgetRankingEntry] {
        tour == .wta ? payload.rankings.wta : payload.rankings.atp
    }

    static var liveMatch: WidgetLiveMatch? {
        payload.liveMatches.first
    }

    static var upcomingMatches: [WidgetUpcomingMatch] {
        let now = Date()
        let upcoming = payload.upcomingMatches.filter { match in
            guard let start = match.startTime else { return true }
            return start > now
        }
        let pool = upcoming.isEmpty ? payload.upcomingMatches : upcoming
        return Array(pool.prefix(6))
    }

    static var previewTour: TourPreference { .atp }
}
