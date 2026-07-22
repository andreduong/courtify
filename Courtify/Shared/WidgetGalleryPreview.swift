import SwiftUI

/// Shared gallery / share preview for a catalog item — same SwiftUI views as WidgetKit.
struct WidgetGalleryPreview: View {
    let item: CourtifyWidgetCatalog.Item
    let favoritePlayer: TennisPlayer?
    let favoritePlayerID: String
    let tour: TourPreference
    let payload: WidgetDataPayload?

    var body: some View {
        previewContent
            .environment(\.showsWidgetMadeByStamp, false)
    }

    @ViewBuilder
    private var previewContent: some View {
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
                entries: WidgetPreviewSamples.rankings(for: .atp),
                limit: 5,
                showsRefreshHint: false,
                widgetID: "atp-medium"
            )
        case "atp-large":
            RankingsLargeWidgetView(
                tour: .atp,
                entries: WidgetPreviewSamples.rankings(for: .atp),
                showsRefreshHint: false,
                widgetID: "atp-large"
            )
        case "wta-medium":
            RankingsWidgetView(
                tour: .wta,
                entries: WidgetPreviewSamples.rankings(for: .wta),
                limit: 5,
                showsRefreshHint: false,
                widgetID: "wta-medium"
            )
        case "wta-large":
            RankingsLargeWidgetView(
                tour: .wta,
                entries: WidgetPreviewSamples.rankings(for: .wta),
                showsRefreshHint: false,
                widgetID: "wta-large"
            )
        case "live":
            LiveScoresWidgetView(
                match: WidgetPreviewSamples.galleryLiveMatch,
                showsRefreshHint: false,
                widgetID: "live"
            )
        case "order":
            OrderOfPlayListView(
                matches: WidgetPreviewSamples.galleryOrderMatches,
                showsRefreshHint: false,
                widgetID: "order"
            )
        case "lock-badge":
            LockScreenCircularBadgeView(slam: LockScreenGallerySamples.slam, showsPreviewPlate: true)
                .frame(width: 72, height: 72)
        case "lock-badge-rect":
            LockScreenRectangularBadgeView(slam: LockScreenGallerySamples.slam, showsPreviewPlate: true)
                .frame(width: 158, height: 68)
        case "lock-rank":
            LockScreenCircularRankView(player: LockScreenGallerySamples.player, showsPreviewPlate: true)
                .frame(width: 72, height: 72)
        case "lock-player":
            LockScreenRectangularFavoriteView(player: LockScreenGallerySamples.player, showsPreviewPlate: true)
                .frame(width: 158, height: 68)
        case "lock-season":
            LockScreenCircularSeasonView(
                player: LockScreenGallerySamples.player,
                tour: LockScreenGallerySamples.tour,
                showsPreviewPlate: true
            )
            .frame(width: 72, height: 72)
        case "lock-season-rect":
            LockScreenRectangularSeasonView(
                player: LockScreenGallerySamples.player,
                tour: LockScreenGallerySamples.tour,
                showsPreviewPlate: true
            )
            .frame(width: 158, height: 68)
        case "lock-countdown":
            LockScreenCircularCountdownView(
                tour: LockScreenGallerySamples.tour,
                forceSlam: LockScreenGallerySamples.slam,
                showsPreviewPlate: true
            )
            .frame(width: 72, height: 72)
        case "lock-next":
            LockScreenRectangularNextView(
                tour: LockScreenGallerySamples.tour,
                forceSlam: LockScreenGallerySamples.slam,
                showsPreviewPlate: true
            )
            .frame(width: 158, height: 68)
        case "lock-live":
            LockScreenRectangularLiveView(match: LockScreenGallerySamples.liveMatch, showsPreviewPlate: true)
                .frame(width: 158, height: 68)
        default:
            EmptyView()
        }
    }
}
