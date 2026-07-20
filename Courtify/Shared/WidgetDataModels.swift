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
        guard let parsedUpdatedAt = WidgetDataPayload.date(fromISO8601: updatedAtString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .updatedAt,
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(updatedAtString)"
            )
        }
        updatedAt = parsedUpdatedAt
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

    init(
        id: Int?,
        tour: String,
        tournament: String?,
        court: String?,
        status: String?,
        score: String?,
        gameScore: String?,
        server: Int?,
        player1: WidgetPlayer,
        player2: WidgetPlayer
    ) {
        self.id = id
        self.tour = tour
        self.tournament = tournament
        self.court = court
        self.status = status
        self.score = score
        self.gameScore = gameScore
        self.server = server
        self.player1 = player1
        self.player2 = player2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleIntIfPresent(forKey: .id)
        tour = try container.decode(String.self, forKey: .tour)
        tournament = try container.decodeIfPresent(String.self, forKey: .tournament)
        court = try container.decodeIfPresent(String.self, forKey: .court)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        score = try container.decodeIfPresent(String.self, forKey: .score)
        gameScore = try container.decodeIfPresent(String.self, forKey: .gameScore)
        server = try container.decodeFlexibleIntIfPresent(forKey: .server)
        player1 = try container.decode(WidgetPlayer.self, forKey: .player1)
        player2 = try container.decode(WidgetPlayer.self, forKey: .player2)
    }

    private enum CodingKeys: String, CodingKey {
        case id, tour, tournament, court, status, score, gameScore, server, player1, player2
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

    init(
        id: Int?,
        tour: String,
        tournament: String?,
        court: String?,
        round: String?,
        startTime: Date?,
        player1: WidgetPlayer,
        player2: WidgetPlayer
    ) {
        self.id = id
        self.tour = tour
        self.tournament = tournament
        self.court = court
        self.round = round
        self.startTime = startTime
        self.player1 = player1
        self.player2 = player2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleIntIfPresent(forKey: .id)
        tour = try container.decode(String.self, forKey: .tour)
        tournament = try container.decodeIfPresent(String.self, forKey: .tournament)
        court = try container.decodeIfPresent(String.self, forKey: .court)
        round = try container.decodeIfPresent(String.self, forKey: .round)
        player1 = try container.decode(WidgetPlayer.self, forKey: .player1)
        player2 = try container.decode(WidgetPlayer.self, forKey: .player2)

        if let startTimeString = try container.decodeIfPresent(String.self, forKey: .startTime) {
            startTime = WidgetDataPayload.date(fromISO8601: startTimeString)
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

    init(id: Int?, name: String, country: String?, imageUrl: String?) {
        self.id = id
        self.name = name
        self.country = country
        self.imageUrl = imageUrl
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
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let legacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    /// Worker `updatedAt` values use `toISOString()` (fractional seconds).
    static func date(fromISO8601 string: String) -> Date? {
        iso8601WithFractionalSeconds.date(from: string)
            ?? iso8601.date(from: string)
            ?? legacyDateFormatter.date(from: string)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        if let int = try? decode(Int.self, forKey: key) { return int }
        if let string = try? decode(String.self, forKey: key) { return Int(string) }
        return nil
    }
}
