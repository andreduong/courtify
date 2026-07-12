import Foundation

struct WidgetDataPayload: Codable {
    let updatedAt: Date
    let liveMatches: [WidgetLiveMatch]
    let upcomingMatches: [WidgetUpcomingMatch]
    let rankings: WidgetRankings
    let meta: WidgetMeta?

    enum CodingKeys: String, CodingKey {
        case updatedAt, liveMatches, upcomingMatches, rankings, meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = ISO8601DateFormatter().date(from: updatedAtString) ?? Date()
        liveMatches = try container.decodeIfPresent([WidgetLiveMatch].self, forKey: .liveMatches) ?? []
        upcomingMatches = try container.decodeIfPresent([WidgetUpcomingMatch].self, forKey: .upcomingMatches) ?? []
        rankings = try container.decode(WidgetRankings.self, forKey: .rankings)
        meta = try container.decodeIfPresent(WidgetMeta.self, forKey: .meta)
    }
}

struct WidgetLiveMatch: Codable, Identifiable {
    let id: Int?
    let tour: String
    let tournament: String?
    let court: String?
    let status: String?
    let score: String?
    let gameScore: String?
    let server: Int?
    let player1: WidgetPlayer
    let player2: WidgetPlayer

    var displayID: String {
        if let id { return String(id) }
        return "\(player1.id ?? 0)-\(player2.id ?? 0)"
    }
}

struct WidgetUpcomingMatch: Codable, Identifiable {
    let id: Int?
    let tour: String
    let tournament: String?
    let court: String?
    let round: String?
    let startTime: Date?
    let player1: WidgetPlayer
    let player2: WidgetPlayer

    var displayID: String {
        if let id { return String(id) }
        return "\(player1.id ?? 0)-\(player2.id ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case id, tour, tournament, court, round, startTime, player1, player2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        tour = try container.decode(String.self, forKey: .tour)
        tournament = try container.decodeIfPresent(String.self, forKey: .tournament)
        court = try container.decodeIfPresent(String.self, forKey: .court)
        round = try container.decodeIfPresent(String.self, forKey: .round)
        player1 = try container.decode(WidgetPlayer.self, forKey: .player1)
        player2 = try container.decode(WidgetPlayer.self, forKey: .player2)

        if let startTimeString = try container.decodeIfPresent(String.self, forKey: .startTime) {
            startTime = ISO8601DateFormatter().date(from: startTimeString)
                ?? WidgetDataPayload.dateFormatter.date(from: startTimeString)
        } else {
            startTime = nil
        }
    }
}

struct WidgetPlayer: Codable {
    let id: Int?
    let name: String
    let country: String?
    let imageUrl: String?

    var imageURL: URL? {
        guard let imageUrl, !imageUrl.isEmpty else { return nil }
        return URL(string: imageUrl)
    }
}

struct WidgetRankingEntry: Codable, Identifiable {
    var id: Int { rank ?? 0 }
    let rank: Int?
    let points: Int?
    let player: WidgetPlayer
}

struct WidgetRankings: Codable {
    let atp: [WidgetRankingEntry]
    let wta: [WidgetRankingEntry]
}

struct WidgetMeta: Codable {
    let sources: WidgetMetaSources?
}

struct WidgetMetaSources: Codable {
    let live: String?
    let atpRankings: String?
    let wtaRankings: String?
    let upcoming: String?
}

extension WidgetDataPayload {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
