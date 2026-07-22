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
        /// Shown next to the section title (`Free` / `Premium`).
        var accessLabel: AccessLabel? = nil
        let items: [Item]

        enum AccessLabel: String {
            case free = "Free"
            case premium = "Premium"
        }
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
        Section(id: "favorite", title: "Favorite player", accessLabel: .free, items: [
            Item(id: "favorite", title: "Favorite player", size: .small, kind: favoritePlayerKind, placement: .homeScreen, isFree: true),
            Item(id: "favorite-medium", title: "Favorite player", size: .medium, kind: favoritePlayerKind, placement: .homeScreen, isFree: true),
        ]),
        // Lock Screen chapter sits right after the home favorite: it is expected to
        // be the second-most-popular category, and leading it with the (free)
        // lock-screen Favorite player keeps a thematic bridge across the visual
        // shift from colorful home cards to frosted accessory plates.
        Section(
            id: "lock-favorite",
            title: "Favorite player",
            subtitle: "Rank and season stats on your Lock Screen.",
            accessLabel: .free,
            items: [
                Item(id: "lock-rank", title: "Rank", size: .small, kind: lockScreenRankKind, placement: .lockScreen, isFree: true),
                Item(id: "lock-player", title: "Stats", size: .medium, kind: lockScreenFavoriteKind, placement: .lockScreen, isFree: true),
            ]
        ),
        Section(
            id: "lock-badges",
            title: "Lockscreen Badges",
            subtitle: "Grand Slam badges for your Lock Screen.",
            accessLabel: .premium,
            items: [
                Item(id: "lock-badge", title: "Circular", size: .small, kind: lockScreenBadgeKind, placement: .lockScreen),
                Item(id: "lock-badge-rect", title: "Rectangular", size: .medium, kind: lockScreenBadgeKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-season",
            title: "Season progress",
            subtitle: "Win rate and Grand Slam progress.",
            accessLabel: .premium,
            items: [
                Item(id: "lock-season", title: "Circular", size: .small, kind: lockScreenSeasonKind, placement: .lockScreen),
                Item(id: "lock-season-rect", title: "Rectangular", size: .medium, kind: lockScreenSeasonKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-countdown",
            title: "Tournament countdown",
            subtitle: "Next major on your tour.",
            accessLabel: .premium,
            items: [
                Item(id: "lock-countdown", title: "Circular", size: .small, kind: lockScreenCountdownKind, placement: .lockScreen),
                Item(id: "lock-next", title: "Rectangular", size: .medium, kind: lockScreenNextKind, placement: .lockScreen),
            ]
        ),
        Section(
            id: "lock-live",
            title: "Live score",
            subtitle: "Live match score on the Lock Screen.",
            accessLabel: .premium,
            items: [
                Item(id: "lock-live", title: "Rectangular", size: .medium, kind: lockScreenLiveKind, placement: .lockScreen),
            ]
        ),
        Section(id: "tournaments", title: "Tournament widgets", accessLabel: .premium, items: [
            Item(id: "next-small", title: "Next tournament", size: .small, kind: nextTournamentKind, placement: .homeScreen),
            Item(id: "countdown", title: "Tournament countdown", size: .medium, kind: tournamentCountdownKind, placement: .homeScreen),
            Item(id: "next-large", title: "Next tournament", size: .large, kind: nextTournamentKind, placement: .homeScreen),
            Item(id: "calendar", title: "Season calendar", size: .large, kind: seasonCalendarKind, placement: .homeScreen),
        ]),
        Section(id: "atp", title: "ATP widgets", accessLabel: .premium, items: [
            Item(id: "atp-medium", title: "ATP standings", size: .medium, kind: atpStandingsKind, placement: .homeScreen),
            Item(id: "atp-large", title: "ATP standings", size: .large, kind: atpStandingsKind, placement: .homeScreen),
        ]),
        Section(id: "wta", title: "WTA widgets", accessLabel: .premium, items: [
            Item(id: "wta-medium", title: "WTA standings", size: .medium, kind: wtaStandingsKind, placement: .homeScreen),
            Item(id: "wta-large", title: "WTA standings", size: .large, kind: wtaStandingsKind, placement: .homeScreen),
        ]),
        Section(id: "live", title: "Live widgets", accessLabel: .premium, items: [
            Item(id: "live", title: "Live scores", size: .small, kind: liveScoresKind, placement: .homeScreen),
            Item(id: "order", title: "Order of play", size: .large, kind: orderOfPlayKind, placement: .homeScreen),
        ]),
    ]

    static var allItems: [Item] {
        sections.flatMap(\.items)
    }

    static func item(id: String) -> Item? {
        allItems.first { $0.id == id }
    }
}
