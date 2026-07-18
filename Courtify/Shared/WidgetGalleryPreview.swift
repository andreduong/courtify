import SwiftUI

/// Shared gallery / share preview for a catalog item — same SwiftUI views as WidgetKit.
struct WidgetGalleryPreview: View {
    let item: CourtifyWidgetCatalog.Item
    let favoritePlayer: TennisPlayer?
    let favoritePlayerID: String
    let tour: TourPreference
    let payload: WidgetDataPayload?

    var body: some View {
        switch item.id {
        case "favorite":
            FavoritePlayerWidgetView(player: favoritePlayer, widgetID: "favorite")
                .id(favoritePlayerID)
        case "favorite-medium":
            FavoritePlayerMediumWidgetView(player: favoritePlayer, widgetID: "favorite-medium")
                .id(favoritePlayerID)
        case "next-small":
            NextTournamentSmallView(tour: tour)
        case "countdown":
            TournamentCountdownView(tour: tour)
        case "next-large":
            NextTournamentLargeView(tour: tour)
        case "calendar":
            SeasonCalendarView(tour: tour)
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
        case "lock-rank":
            LockScreenCircularRankView(player: favoritePlayer)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.35)
                }
        case "lock-countdown":
            LockScreenCircularCountdownView(tour: tour)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.35)
                }
        case "lock-next":
            LockScreenRectangularNextView(tour: tour)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.62), lineWidth: 1.2)
                }
        case "lock-live":
            LockScreenRectangularLiveView(match: payload?.liveMatches.first)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.62), lineWidth: 1.2)
                }
        default:
            EmptyView()
        }
    }
}
