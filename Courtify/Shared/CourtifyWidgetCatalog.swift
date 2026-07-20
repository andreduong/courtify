import CoreGraphics
import Foundation

/// Single source of truth for the in-app Widgets gallery and WidgetKit kinds.
/// Every gallery card maps to a registered home-screen or Lock Screen widget kind.
enum CourtifyWidgetCatalog {
    enum Size: String {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var previewHeight: CGFloat {
            switch self {
            case .small: 165
            case .medium: 165
            case .large: 330
            }
        }
    }

    enum Placement {
        case homeScreen
        case lockScreen
    }

    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let size: Size
        let kind: String
        let placement: Placement
        var isFree: Bool = false
    }

    struct Section: Identifiable {
        let id: String
        let title: String
        /// Box Box–style gallery / picker subtitle under the section title.
        var subtitle: String? = nil
        let items: [Item]
    }

    // MARK: - WidgetKit kinds (must match registered `Widget` kinds)

    static let favoritePlayerKind = "FavoritePlayerWidget"
    static let nextTournamentKind = "NextTournamentWidget"
    static let tournamentCountdownKind = "TournamentCountdownWidget"
    static let seasonCalendarKind = "SeasonCalendarWidget"
    static let atpStandingsKind = "ATPStandingsWidget"
    static let wtaStandingsKind = "WTAStandingsWidget"
    static let liveScoresKind = "LiveScoresWidget"
    static let orderOfPlayKind = "OrderOfPlayWidget"
    static let lockScreenBadgeKind = "LockScreenBadgeWidget"
    static let lockScreenRankKind = "LockScreenRankWidget"
    static let lockScreenFavoriteKind = "LockScreenFavoriteWidget"
    static let lockScreenSeasonKind = "LockScreenSeasonWidget"
    static let lockScreenCountdownKind = "LockScreenCountdownWidget"
    static let lockScreenNextKind = "LockScreenNextWidget"
    static let lockScreenLiveKind = "LockScreenLiveWidget"

    /// Unique WidgetKit kinds in registration order (Lock Screen fan-first).
    static let allKinds: [String] = [
        favoritePlayerKind,
        nextTournamentKind,
        tournamentCountdownKind,
        seasonCalendarKind,
        atpStandingsKind,
        wtaStandingsKind,
        liveScoresKind,
        orderOfPlayKind,
        lockScreenBadgeKind,
        lockScreenRankKind,
        lockScreenFavoriteKind,
        lockScreenSeasonKind,
        lockScreenCountdownKind,
        lockScreenNextKind,
        lockScreenLiveKind,
    ]

    static let sections: [Section] = [
        Section(id: "favorite", title: "Favorite player", items: [
            Item(id: "favorite", title: "Favorite player", size: .small, kind: favoritePlayerKind, placement: .homeScreen, isFree: true),
            Item(id: "favorite-medium", title: "Favorite player", size: .medium, kind: favoritePlayerKind, placement: .homeScreen, isFree: true),
        ]),
        Section(id: "tournaments", title: "Tournament widgets", items: [
            Item(id: "next-small", title: "Next tournament", size: .small, kind: nextTournamentKind, placement: .homeScreen),
            Item(id: "countdown", title: "Tournament countdown", size: .medium, kind: tournamentCountdownKind, placement: .homeScreen),
            Item(id: "next-large", title: "Next tournament", size: .large, kind: nextTournamentKind, placement: .homeScreen),
            Item(id: "calendar", title: "Season calendar", size: .large, kind: seasonCalendarKind, placement: .homeScreen),
        ]),
        Section(id: "atp", title: "ATP widgets", items: [
            Item(id: "atp-medium", title: "ATP standings", size: .medium, kind: atpStandingsKind, placement: .homeScreen),
            Item(id: "atp-large", title: "ATP standings", size: .large, kind: atpStandingsKind, placement: .homeScreen),
        ]),
        Section(id: "wta", title: "WTA widgets", items: [
            Item(id: "wta-medium", title: "WTA standings", size: .medium, kind: wtaStandingsKind, placement: .homeScreen),
            Item(id: "wta-large", title: "WTA standings", size: .large, kind: wtaStandingsKind, placement: .homeScreen),
        ]),
        Section(id: "live", title: "Live widgets", items: [
            Item(id: "live", title: "Live scores", size: .small, kind: liveScoresKind, placement: .homeScreen),
            Item(id: "order", title: "Order of play", size: .large, kind: orderOfPlayKind, placement: .homeScreen),
        ]),
        // Lock Screen — hardcore-fan order (mirrors Box Box: badges → favorite → season → countdown → live)
        Section(
            id: "lock-badges",
            title: "Badges",
            subtitle: "Style your Lock Screen with Grand Slam badges. Premium.",
            items: [
                Item(id: "lock-badge", title: "Slam badge", size: .small, kind: lockScreenBadgeKind, placement: .lockScreen),
                Item(id: "lock-badge-rect", title: "Slam badge", size: .medium, kind: lockScreenBadgeKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-favorite",
            title: "Favorite player",
            subtitle: "Rank and season stats for your player. Rank is free.",
            items: [
                Item(id: "lock-rank", title: "Favorite rank", size: .small, kind: lockScreenRankKind, placement: .lockScreen, isFree: true),
                Item(id: "lock-player", title: "Favorite player", size: .medium, kind: lockScreenFavoriteKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-season",
            title: "Season progress",
            subtitle: "Win rate and Grand Slam progress. Premium.",
            items: [
                Item(id: "lock-season", title: "Season progress", size: .small, kind: lockScreenSeasonKind, placement: .lockScreen),
                Item(id: "lock-season-rect", title: "Season progress", size: .medium, kind: lockScreenSeasonKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-countdown",
            title: "Tournament countdown",
            subtitle: "Next major on your tour. Premium.",
            items: [
                Item(id: "lock-countdown", title: "Countdown", size: .small, kind: lockScreenCountdownKind, placement: .lockScreen),
                Item(id: "lock-next", title: "Next tournament", size: .medium, kind: lockScreenNextKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-live",
            title: "Live score",
            subtitle: "Live match score on the Lock Screen. Premium.",
            items: [
                Item(id: "lock-live", title: "Live score", size: .medium, kind: lockScreenLiveKind, placement: .lockScreen),
            ]
        ),
    ]

    static var allItems: [Item] {
        sections.flatMap(\.items)
    }

    static func item(id: String) -> Item? {
        allItems.first { $0.id == id }
    }
}
