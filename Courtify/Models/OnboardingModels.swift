import Foundation

enum TourPreference: String, CaseIterable, Identifiable, Codable {
    case atp = "ATP"
    case wta = "WTA"
    case both = "Both"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .atp: "Men's professional tennis"
        case .wta: "Women's professional tennis"
        case .both: "Follow the full tour"
        }
    }

    var icon: String {
        switch self {
        case .atp: "figure.tennis"
        case .wta: "figure.tennis"
        case .both: "tennisball.fill"
        }
    }
}

struct TennisPlayer: Identifiable, Hashable {
    let id: String
    let name: String
    let tour: TourPreference
    let imageName: String?
    let ranking: Int

    var isCustom: Bool { id.hasPrefix("custom:") }

    var placeholderImageName: String {
        switch tour {
        case .wta: "placeholder-female"
        case .atp, .both: "placeholder-male"
        }
    }

    var resolvedImageName: String {
        if isCustom { return placeholderImageName }
        return imageName ?? placeholderImageName
    }

    /// Transparent full-torso cutout bundled at build time (sourced once from the
    /// official ATP/WTA media CDNs — no runtime fetching, no API cost).
    /// Falls back to the avatar asset for custom players.
    var heroImageName: String {
        if isCustom { return placeholderImageName }
        guard let imageName else { return placeholderImageName }
        return "\(imageName)-hero"
    }

    /// Bundled 2026 season W/L through current tour stop (placeholder until live stats API).
    var seasonRecord: (wins: Int, losses: Int) {
        switch id {
        case "djokovic": return (28, 7)
        case "sinner": return (42, 5)
        case "alcaraz": return (38, 8)
        case "medvedev": return (31, 12)
        case "zverev": return (35, 10)
        case "swiatek": return (40, 6)
        case "sabalenka": return (36, 9)
        case "gauff": return (33, 11)
        case "rybakina": return (29, 10)
        case "pegula": return (27, 12)
        default: return (24, 8)
        }
    }

    /// Pre-blurred full-screen background baked at asset build time (no runtime blur).
    var paywallImageName: String? {
        guard let imageName else { return nil }
        return "\(imageName)-paywall"
    }

    static let topPlayers: [TennisPlayer] = [
        TennisPlayer(id: "djokovic", name: "Novak Djokovic", tour: .atp, imageName: "player-djokovic", ranking: 1),
        TennisPlayer(id: "sinner", name: "Jannik Sinner", tour: .atp, imageName: "player-sinner", ranking: 2),
        TennisPlayer(id: "alcaraz", name: "Carlos Alcaraz", tour: .atp, imageName: "player-alcaraz", ranking: 3),
        TennisPlayer(id: "medvedev", name: "Daniil Medvedev", tour: .atp, imageName: "player-medvedev", ranking: 4),
        TennisPlayer(id: "zverev", name: "Alexander Zverev", tour: .atp, imageName: "player-zverev", ranking: 5),
        TennisPlayer(id: "swiatek", name: "Iga Świątek", tour: .wta, imageName: "player-swiatek", ranking: 1),
        TennisPlayer(id: "sabalenka", name: "Aryna Sabalenka", tour: .wta, imageName: "player-sabalenka", ranking: 2),
        TennisPlayer(id: "gauff", name: "Coco Gauff", tour: .wta, imageName: "player-gauff", ranking: 3),
        TennisPlayer(id: "rybakina", name: "Elena Rybakina", tour: .wta, imageName: "player-rybakina", ranking: 4),
        TennisPlayer(id: "pegula", name: "Jessica Pegula", tour: .wta, imageName: "player-pegula", ranking: 5),
    ]

    static func topFive(for tourPreference: TourPreference) -> [TennisPlayer] {
        switch tourPreference {
        case .atp:
            topPlayers.filter { $0.tour == .atp }.prefix(5).map { $0 }
        case .wta:
            topPlayers.filter { $0.tour == .wta }.prefix(5).map { $0 }
        case .both:
            topPlayers
        }
    }

    static func player(for id: String) -> TennisPlayer? {
        if let featured = topPlayers.first(where: { $0.id == id }) {
            return featured
        }
        guard id.hasPrefix("custom:") else { return nil }
        let parts = id.split(separator: ":", maxSplits: 2)
        guard parts.count == 3,
              let name = String(parts[2]).removingPercentEncoding,
              !name.isEmpty else { return nil }
        let tour: TourPreference = parts[1] == "wta" ? .wta : .atp
        return TennisPlayer(id: id, name: name, tour: tour, imageName: nil, ranking: 0)
    }

    static func displayName(for id: String) -> String? {
        player(for: id)?.name
    }

    static func makeCustomID(name: String, tour: TourPreference) -> String {
        let tourKey = tour == .wta ? "wta" : "atp"
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return "custom:\(tourKey):\(encoded)"
    }
}

enum PlayerSearchCatalog {
    struct Entry: Identifiable, Hashable {
        let name: String
        let tour: TourPreference

        var id: String { "\(tour.rawValue)-\(name)" }

        var atpTourCode: String? {
            guard tour == .atp else { return nil }
            return PlayerSearchCatalog.atpTourCode(for: name)
        }
    }

    private static let atpTourCodes: [String: String] = [
        "Novak Djokovic": "d643",
        "Jannik Sinner": "s0ag",
        "Carlos Alcaraz": "a0e2",
        "Daniil Medvedev": "mm58",
        "Alexander Zverev": "z355",
        "Taylor Fritz": "fb98",
        "Ben Shelton": "s0n0",
        "Hubert Hurkacz": "hb64",
        "Casper Ruud": "r0dg",
        "Andrey Rublev": "re44",
        "Stefanos Tsitsipas": "te51",
        "Tommy Paul": "pl56",
        "Grigor Dimitrov": "d875",
        "Frances Tiafoe": "td51",
        "Holger Rune": "r0la",
        "Sebastian Korda": "kb05",
        "Alex de Minaur": "dh58",
        "Felix Auger-Aliassime": "ag37",
        "Lorenzo Musetti": "m0ej",
        "Matteo Berrettini": "bh60",
    ]

    static func atpTourCode(for name: String) -> String? {
        let folded = fold(name)
        if let exact = atpTourCodes[name] { return exact }
        return atpTourCodes.first { fold($0.key) == folded }?.value
    }

    static func entry(matching name: String, tour: TourPreference) -> Entry? {
        let folded = fold(name)
        return entries.first { $0.tour == tour && fold($0.name) == folded }
            ?? entries.first { fold($0.name) == folded }
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
    }

    /// Bundled name list for zero-API autocomplete in onboarding.
    static let entries: [Entry] = [
        // ATP
        Entry(name: "Novak Djokovic", tour: .atp),
        Entry(name: "Jannik Sinner", tour: .atp),
        Entry(name: "Carlos Alcaraz", tour: .atp),
        Entry(name: "Daniil Medvedev", tour: .atp),
        Entry(name: "Alexander Zverev", tour: .atp),
        Entry(name: "Taylor Fritz", tour: .atp),
        Entry(name: "Ben Shelton", tour: .atp),
        Entry(name: "Hubert Hurkacz", tour: .atp),
        Entry(name: "Casper Ruud", tour: .atp),
        Entry(name: "Andrey Rublev", tour: .atp),
        Entry(name: "Stefanos Tsitsipas", tour: .atp),
        Entry(name: "Tommy Paul", tour: .atp),
        Entry(name: "Grigor Dimitrov", tour: .atp),
        Entry(name: "Frances Tiafoe", tour: .atp),
        Entry(name: "Holger Rune", tour: .atp),
        Entry(name: "Sebastian Korda", tour: .atp),
        Entry(name: "Alex de Minaur", tour: .atp),
        Entry(name: "Felix Auger-Aliassime", tour: .atp),
        Entry(name: "Lorenzo Musetti", tour: .atp),
        Entry(name: "Matteo Berrettini", tour: .atp),
        // WTA
        Entry(name: "Iga Świątek", tour: .wta),
        Entry(name: "Aryna Sabalenka", tour: .wta),
        Entry(name: "Coco Gauff", tour: .wta),
        Entry(name: "Elena Rybakina", tour: .wta),
        Entry(name: "Jessica Pegula", tour: .wta),
        Entry(name: "Qinwen Zheng", tour: .wta),
        Entry(name: "Maria Sakkari", tour: .wta),
        Entry(name: "Jasmine Paolini", tour: .wta),
        Entry(name: "Madison Keys", tour: .wta),
        Entry(name: "Barbora Krejcikova", tour: .wta),
        Entry(name: "Mirra Andreeva", tour: .wta),
        Entry(name: "Paula Badosa", tour: .wta),
        Entry(name: "Danielle Collins", tour: .wta),
        Entry(name: "Emma Navarro", tour: .wta),
        Entry(name: "Beatriz Haddad Maia", tour: .wta),
        Entry(name: "Daria Kasatkina", tour: .wta),
        Entry(name: "Ons Jabeur", tour: .wta),
        Entry(name: "Marketa Vondrousova", tour: .wta),
        Entry(name: "Caroline Wozniacki", tour: .wta),
        Entry(name: "Naomi Osaka", tour: .wta),
    ]

    static func suggestions(query: String, tourPreference: TourPreference, limit: Int = 6) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let needle = fold(trimmed)
        let pool: [Entry]
        switch tourPreference {
        case .atp:
            pool = entries.filter { $0.tour == .atp }
        case .wta:
            pool = entries.filter { $0.tour == .wta }
        case .both:
            pool = entries
        }

        let queryParts = needle.split(separator: " ").map(String.init)

        let ranked = pool.filter { entry in
            let name = fold(entry.name)
            if name.contains(needle) { return true }
            guard queryParts.count >= 2 else { return false }
            let nameParts = name.split(separator: " ").map(String.init)
            guard let queryLast = queryParts.last, let nameLast = nameParts.last else { return false }
            let firstMatches = queryParts.dropLast().allSatisfy { part in
                nameParts.contains { $0.hasPrefix(part) || part.hasPrefix($0) }
            }
            let lastMatches = nameLast.hasPrefix(queryLast)
                || queryLast.hasPrefix(nameLast)
                || levenshtein(nameLast, queryLast) <= 1
            return firstMatches && lastMatches
        }.sorted { lhs, rhs in
            let ll = fold(lhs.name)
            let rl = fold(rhs.name)
            let lStarts = ll.hasPrefix(needle)
            let rStarts = rl.hasPrefix(needle)
            if lStarts != rStarts { return lStarts }
            if ll.count != rl.count { return ll.count < rl.count }
            return ll < rl
        }

        return Array(ranked.prefix(limit))
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 0 }
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0 ... rhs.count)
        for (i, leftChar) in lhs.enumerated() {
            var current = [i + 1]
            for (j, rightChar) in rhs.enumerated() {
                let insertions = previous[j + 1] + 1
                let deletions = current[j] + 1
                let substitutions = previous[j] + (leftChar == rightChar ? 0 : 1)
                current.append(min(insertions, deletions, substitutions))
            }
            previous = current
        }
        return previous.last ?? max(lhs.count, rhs.count)
    }
}

enum GrandSlam: String, CaseIterable, Identifiable, Codable {
    case australianOpen = "Australian Open"
    case frenchOpen = "French Open"
    case wimbledon = "Wimbledon"
    case usOpen = "US Open"

    var id: String { rawValue }

    var location: String {
        switch self {
        case .australianOpen: "Melbourne, Australia"
        case .frenchOpen: "Paris, France"
        case .wimbledon: "London, England"
        case .usOpen: "New York, USA"
        }
    }

    var surface: String {
        switch self {
        case .australianOpen: "Hard"
        case .frenchOpen: "Clay"
        case .wimbledon: "Grass"
        case .usOpen: "Hard"
        }
    }

    var accentColor: UInt {
        switch self {
        case .australianOpen: 0x0085CA
        case .frenchOpen: 0xE35205
        case .wimbledon: 0x006633
        case .usOpen: 0x0C2340
        }
    }

    var logoImageName: String {
        switch self {
        case .australianOpen: "slam-australian-open"
        case .frenchOpen: "slam-french-open"
        case .wimbledon: "slam-wimbledon"
        case .usOpen: "slam-us-open"
        }
    }
}
