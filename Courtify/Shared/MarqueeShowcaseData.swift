import Foundation

/// Static showcase content for splash/paywall marquees.
/// Bundled once — no runtime network. Faces use existing `player-*-hero` assets;
/// classic matches are historical scorecards (Federer / Nadal / Serena included by name).
enum MarqueeShowcaseData {
    /// Featured faces we ship as transparent torso cutouts.
    static let facePlayerIDs: [String] = [
        "alcaraz",
        "djokovic",
        "sinner",
        "swiatek",
        "sabalenka",
        "gauff",
    ]

    static func player(id: String) -> TennisPlayer? {
        TennisPlayer.player(for: id)
    }

    static func player(at index: Int) -> TennisPlayer? {
        guard !facePlayerIDs.isEmpty else { return TennisPlayer.topPlayers.first }
        let id = facePlayerIDs[index % facePlayerIDs.count]
        return player(id: id) ?? TennisPlayer.topPlayers.first
    }

    /// Iconic scorelines for live-style marquee cards (status `CLASSIC`).
    static let classicMatches: [WidgetLiveMatch] = [
        WidgetLiveMatch(
            id: 2008,
            tour: "ATP",
            tournament: "Wimbledon 2008",
            court: "Centre Court",
            status: "CLASSIC",
            score: "6-4 6-4 6-7 6-7 9-7",
            gameScore: nil,
            server: nil,
            player1: WidgetPlayer(id: 1, name: "R. Federer", country: "SUI", imageUrl: nil),
            player2: WidgetPlayer(id: 2, name: "R. Nadal", country: "ESP", imageUrl: nil)
        ),
        WidgetLiveMatch(
            id: 2012,
            tour: "ATP",
            tournament: "Australian Open 2012",
            court: "Rod Laver Arena",
            status: "CLASSIC",
            score: "5-7 6-4 6-2 6-7 7-5",
            gameScore: nil,
            server: nil,
            player1: WidgetPlayer(id: 3, name: "N. Djokovic", country: "SRB", imageUrl: nil),
            player2: WidgetPlayer(id: 2, name: "R. Nadal", country: "ESP", imageUrl: nil)
        ),
        WidgetLiveMatch(
            id: 2024,
            tour: "ATP",
            tournament: "French Open 2024",
            court: "Court Philippe-Chatrier",
            status: "CLASSIC",
            score: "2-6 6-3 3-6 6-4 6-3",
            gameScore: nil,
            server: nil,
            player1: WidgetPlayer(id: 4, name: "C. Alcaraz", country: "ESP", imageUrl: nil),
            player2: WidgetPlayer(id: 5, name: "J. Sinner", country: "ITA", imageUrl: nil)
        ),
        WidgetLiveMatch(
            id: 2009,
            tour: "WTA",
            tournament: "Wimbledon 2009",
            court: "Centre Court",
            status: "CLASSIC",
            score: "7-6 6-2",
            gameScore: nil,
            server: nil,
            player1: WidgetPlayer(id: 6, name: "S. Williams", country: "USA", imageUrl: nil),
            player2: WidgetPlayer(id: 7, name: "V. Williams", country: "USA", imageUrl: nil)
        ),
        WidgetLiveMatch(
            id: 2019,
            tour: "ATP",
            tournament: "Wimbledon 2019",
            court: "Centre Court",
            status: "CLASSIC",
            score: "7-6 1-6 7-6 4-6 13-12",
            gameScore: nil,
            server: nil,
            player1: WidgetPlayer(id: 3, name: "N. Djokovic", country: "SRB", imageUrl: nil),
            player2: WidgetPlayer(id: 1, name: "R. Federer", country: "SUI", imageUrl: nil)
        ),
    ]

    static func classicMatch(at index: Int) -> WidgetLiveMatch {
        classicMatches[index % classicMatches.count]
    }

    /// Modern “live” card still useful in the strip.
    static var modernLiveMatch: WidgetLiveMatch {
        WidgetPreviewSamples.liveMatch ?? classicMatches[2]
    }
}
