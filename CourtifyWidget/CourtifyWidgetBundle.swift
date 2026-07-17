import WidgetKit
import SwiftUI

@main
struct CourtifyWidgetBundle: WidgetBundle {
    var body: some Widget {
        FavoritePlayerWidget()
        NextTournamentWidget()
        SeasonCalendarWidget()
        ATPStandingsWidget()
        WTAStandingsWidget()
        LiveScoresWidget()
        OrderOfPlayWidget()
        LockScreenRankWidget()
        LockScreenCountdownWidget()
        LockScreenNextWidget()
    }
}
