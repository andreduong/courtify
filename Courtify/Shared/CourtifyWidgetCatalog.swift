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
    static let lockScreenRankKind = "LockScreenRankWidget"
    static let lockScreenCountdownKind = "LockScreenCountdownWidget"
    static let lockScreenNextKind = "LockScreenNextWidget"
    static let lockScreenLiveKind = "LockScreenLiveWidget"

    /// Unique WidgetKit kinds in registration order.
    static let allKinds: [String] = [
        favoritePlayerKind,
        nextTournamentKind,
        tournamentCountdownKind,
        seasonCalendarKind,
        atpStandingsKind,
        wtaStandingsKind,
        liveScoresKind,
        orderOfPlayKind,
        lockScreenRankKind,
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
        Section(id: "lock", title: "Lock Screen", items: [
            Item(id: "lock-rank", title: "Favorite rank", size: .small, kind: lockScreenRankKind, placement: .lockScreen, isFree: true),
            Item(id: "lock-countdown", title: "Countdown", size: .small, kind: lockScreenCountdownKind, placement: .lockScreen),
            Item(id: "lock-next", title: "Next tournament", size: .medium, kind: lockScreenNextKind, placement: .lockScreen),
            Item(id: "lock-live", title: "Live score", size: .medium, kind: lockScreenLiveKind, placement: .lockScreen),
        ]),
    ]

    static var allItems: [Item] {
        sections.flatMap(\.items)
    }

    static func item(id: String) -> Item? {
        allItems.first { $0.id == id }
    }
}
