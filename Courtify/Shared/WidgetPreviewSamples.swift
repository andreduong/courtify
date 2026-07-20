import Foundation

/// Rich placeholder data for the system widget gallery and Xcode previews.
enum WidgetPreviewSamples {
    static var payload: WidgetDataPayload { WidgetMockData.sample }

    static var favoritePlayer: TennisPlayer {
        TennisPlayer.player(for: "alcaraz") ?? TennisPlayer.topPlayers[2]
    }

    static func rankings(for tour: TourPreference) -> [WidgetRankingEntry] {
        tour == .wta ? payload.rankings.wta : payload.rankings.atp
    }

    static var liveMatch: WidgetLiveMatch? {
        galleryLiveMatch
    }

    static var upcomingMatches: [WidgetUpcomingMatch] {
        galleryOrderMatches
    }

    static var previewTour: TourPreference { .atp }

    /// Alcaraz vs Sinner — Wimbledon Centre Court (in-app gallery + Lock Screen live).
    static let galleryLiveMatch = WidgetLiveMatch(
        id: 901,
        tour: "ATP",
        tournament: "Wimbledon",
        court: "Centre Court",
        status: "LIVE",
        score: "6-4 3-6 4-4",
        gameScore: "40-30",
        server: 1,
        player1: WidgetPlayer(id: 5993, name: "Carlos Alcaraz", country: "ESP", imageUrl: nil),
        player2: WidgetPlayer(id: 5992, name: "Jannik Sinner", country: "ITA", imageUrl: nil)
    )

    /// Australian Open order-of-play slate for gallery / share previews.
    static let galleryOrderMatches: [WidgetUpcomingMatch] = [
        WidgetUpcomingMatch(
            id: 801,
            tour: "ATP",
            tournament: "Australian Open",
            court: "Rod Laver Arena",
            round: "QF",
            startTime: Date().addingTimeInterval(3600),
            player1: WidgetPlayer(id: 5992, name: "Jannik Sinner", country: "ITA", imageUrl: nil),
            player2: WidgetPlayer(id: 5993, name: "Carlos Alcaraz", country: "ESP", imageUrl: nil)
        ),
        WidgetUpcomingMatch(
            id: 802,
            tour: "WTA",
            tournament: "Australian Open",
            court: "Rod Laver Arena",
            round: "QF",
            startTime: Date().addingTimeInterval(7200),
            player1: WidgetPlayer(id: 7002, name: "Aryna Sabalenka", country: "BLR", imageUrl: nil),
            player2: WidgetPlayer(id: 7001, name: "Iga Świątek", country: "POL", imageUrl: nil)
        ),
        WidgetUpcomingMatch(
            id: 803,
            tour: "ATP",
            tournament: "Australian Open",
            court: "Margaret Court Arena",
            round: "QF",
            startTime: Date().addingTimeInterval(10_800),
            player1: WidgetPlayer(id: 5994, name: "Novak Djokovic", country: "SRB", imageUrl: nil),
            player2: WidgetPlayer(id: 5996, name: "Alexander Zverev", country: "GER", imageUrl: nil)
        ),
        WidgetUpcomingMatch(
            id: 804,
            tour: "WTA",
            tournament: "Australian Open",
            court: "Margaret Court Arena",
            round: "QF",
            startTime: Date().addingTimeInterval(14_400),
            player1: WidgetPlayer(id: 7003, name: "Coco Gauff", country: "USA", imageUrl: nil),
            player2: WidgetPlayer(id: 7004, name: "Elena Rybakina", country: "KAZ", imageUrl: nil)
        ),
        WidgetUpcomingMatch(
            id: 805,
            tour: "ATP",
            tournament: "Australian Open",
            court: "John Cain Arena",
            round: "4R",
            startTime: Date().addingTimeInterval(18_000),
            player1: WidgetPlayer(id: 5997, name: "Taylor Fritz", country: "USA", imageUrl: nil),
            player2: WidgetPlayer(id: 5998, name: "Ben Shelton", country: "USA", imageUrl: nil)
        ),
        WidgetUpcomingMatch(
            id: 806,
            tour: "WTA",
            tournament: "Australian Open",
            court: "John Cain Arena",
            round: "4R",
            startTime: Date().addingTimeInterval(21_600),
            player1: WidgetPlayer(id: 7005, name: "Jessica Pegula", country: "USA", imageUrl: nil),
            player2: WidgetPlayer(id: 7007, name: "Madison Keys", country: "USA", imageUrl: nil)
        ),
    ]
}
