import SwiftUI

/// Shared gallery / share preview for a catalog item — same SwiftUI views as WidgetKit.
struct WidgetGalleryPreview: View {
    let item: CourtifyWidgetCatalog.Item
    let favoritePlayer: TennisPlayer?
    let favoritePlayerID: String
    let tour: TourPreference
    let payload: WidgetDataPayload?

    private var favoriteSlam: GrandSlam? {
        let raw = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoriteGrandSlam) ?? ""
        return GrandSlam(rawValue: raw)
    }

    var body: some View {
        switch item.id {
        case "favorite":
            FavoritePlayerWidgetView(player: favoritePlayer, widgetID: "favorite")
                .id(favoritePlayerID)
        case "favorite-medium":
            FavoritePlayerMediumWidgetView(player: favoritePlayer, widgetID: "favorite-medium")
                .id(favoritePlayerID)
        case "next-small":
            NextTournamentSmallView(tour: tour, widgetID: "next-small")
        case "countdown":
            TournamentCountdownView(tour: tour, widgetID: "countdown")
        case "next-large":
            NextTournamentLargeView(tour: tour, widgetID: "next-large")
        case "calendar":
            SeasonCalendarView(tour: tour, widgetID: "calendar")
        case "atp-medium":
            RankingsWidgetView(
                tour: .atp,
                entries: payload?.rankings.atp ?? [],
                limit: 5,
                showsRefreshHint: true,
                widgetID: "atp-medium"
            )
        case "atp-large":
            RankingsLargeWidgetView(
                tour: .atp,
                entries: payload?.rankings.atp ?? [],
                showsRefreshHint: true,
                widgetID: "atp-large"
            )
        case "wta-medium":
            RankingsWidgetView(
                tour: .wta,
                entries: payload?.rankings.wta ?? [],
                limit: 5,
                showsRefreshHint: true,
                widgetID: "wta-medium"
            )
        case "wta-large":
            RankingsLargeWidgetView(
                tour: .wta,
                entries: payload?.rankings.wta ?? [],
                showsRefreshHint: true,
                widgetID: "wta-large"
            )
        case "live":
            LiveScoresWidgetView(
                match: payload?.liveMatches.first,
                showsRefreshHint: true,
                widgetID: "live"
            )
        case "order":
            OrderOfPlayListView(
                matches: payload?.upcomingMatches ?? [],
                showsRefreshHint: true,
                widgetID: "order"
            )
        case "lock-badge":
            LockScreenGalleryFrame(kind: .circular) {
                LockScreenCircularBadgeView(slam: favoriteSlam, showsPreviewPlate: true)
            }
        case "lock-badge-rect":
            LockScreenGalleryFrame(kind: .rectangular) {
                LockScreenRectangularBadgeView(slam: favoriteSlam, showsPreviewPlate: true)
            }
        case "lock-rank":
            LockScreenGalleryFrame(kind: .circular) {
                LockScreenCircularRankView(player: favoritePlayer, showsPreviewPlate: true)
            }
        case "lock-player":
            LockScreenGalleryFrame(kind: .rectangular) {
                LockScreenRectangularFavoriteView(player: favoritePlayer, showsPreviewPlate: true)
            }
        case "lock-season":
            LockScreenGalleryFrame(kind: .circular) {
                LockScreenCircularSeasonView(player: favoritePlayer, tour: tour, showsPreviewPlate: true)
            }
        case "lock-season-rect":
            LockScreenGalleryFrame(kind: .rectangular) {
                LockScreenRectangularSeasonView(player: favoritePlayer, tour: tour, showsPreviewPlate: true)
            }
        case "lock-countdown":
            LockScreenGalleryFrame(kind: .circular) {
                LockScreenCircularCountdownView(tour: tour, showsPreviewPlate: true)
            }
        case "lock-next":
            LockScreenGalleryFrame(kind: .rectangular) {
                LockScreenRectangularNextView(tour: tour, showsPreviewPlate: true)
            }
        case "lock-live":
            LockScreenGalleryFrame(kind: .rectangular) {
                LockScreenRectangularLiveView(match: payload?.liveMatches.first, showsPreviewPlate: true)
            }
        default:
            EmptyView()
        }
    }
}
