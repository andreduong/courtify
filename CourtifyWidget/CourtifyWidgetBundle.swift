import WidgetKit
import SwiftUI

@main
struct CourtifyWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen kinds (≤10 per builder block). Lock Screen kinds via nested `.body`.
        FavoritePlayerWidget()
        NextTournamentWidget()
        TournamentCountdownWidget()
        SeasonCalendarWidget()
        ATPStandingsWidget()
        WTAStandingsWidget()
        LiveScoresWidget()
        OrderOfPlayWidget()
        CourtifyLockScreenWidgetBundle().body
    }
}

/// Nested bundle so we can exceed the 10-kind `WidgetBundleBuilder` limit.
/// Use `.body` (not the bundle type itself) — nesting `WidgetBundle` as a `Widget` fails to type-check.
struct CourtifyLockScreenWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockScreenRankWidget()
        LockScreenCountdownWidget()
        LockScreenNextWidget()
        LockScreenLiveWidget()
    }
}
