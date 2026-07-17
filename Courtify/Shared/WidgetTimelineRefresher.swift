import WidgetKit

enum WidgetTimelineRefresher {
    static let favoritePlayerKind = "FavoritePlayerWidget"
    static let nextTournamentKind = "NextTournamentWidget"
    static let seasonCalendarKind = "SeasonCalendarWidget"
    static let atpStandingsKind = "ATPStandingsWidget"
    static let wtaStandingsKind = "WTAStandingsWidget"
    static let liveScoresKind = "LiveScoresWidget"
    static let orderOfPlayKind = "OrderOfPlayWidget"
    static let lockScreenRankKind = "LockScreenRankWidget"
    static let lockScreenCountdownKind = "LockScreenCountdownWidget"
    static let lockScreenNextKind = "LockScreenNextWidget"

    private static let allKinds = [
        favoritePlayerKind,
        nextTournamentKind,
        seasonCalendarKind,
        atpStandingsKind,
        wtaStandingsKind,
        liveScoresKind,
        orderOfPlayKind,
        lockScreenRankKind,
        lockScreenCountdownKind,
        lockScreenNextKind,
    ]

    static func reloadAll() {
        for kind in allKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
