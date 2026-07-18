import WidgetKit

enum WidgetTimelineRefresher {
    static let favoritePlayerKind = CourtifyWidgetCatalog.favoritePlayerKind
    static let nextTournamentKind = CourtifyWidgetCatalog.nextTournamentKind
    static let tournamentCountdownKind = CourtifyWidgetCatalog.tournamentCountdownKind
    static let seasonCalendarKind = CourtifyWidgetCatalog.seasonCalendarKind
    static let atpStandingsKind = CourtifyWidgetCatalog.atpStandingsKind
    static let wtaStandingsKind = CourtifyWidgetCatalog.wtaStandingsKind
    static let liveScoresKind = CourtifyWidgetCatalog.liveScoresKind
    static let orderOfPlayKind = CourtifyWidgetCatalog.orderOfPlayKind
    static let lockScreenRankKind = CourtifyWidgetCatalog.lockScreenRankKind
    static let lockScreenCountdownKind = CourtifyWidgetCatalog.lockScreenCountdownKind
    static let lockScreenNextKind = CourtifyWidgetCatalog.lockScreenNextKind
    static let lockScreenLiveKind = CourtifyWidgetCatalog.lockScreenLiveKind

    static func reloadAll() {
        for kind in CourtifyWidgetCatalog.allKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
