import Foundation
import UIKit

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

    /// Bundled transparent cutout for this player when one shipped in the asset
    /// catalog. Featured players use `player-{id}-hero`; search-catalog and top-10
    /// payload names resolve `player-{name-slug}-hero` (downloaded once at dev time
    /// from the tour CDNs — zero runtime API cost). `nil` when no cutout exists.
    var bundledHeroCutoutName: String? {
        if let imageName { return "\(imageName)-hero" }
        return TennisPlayer.sluggedHeroAsset(for: name)
    }

    private static var heroAssetLookupCache: [String: String?] = [:]
    private static let heroAssetLookupLock = NSLock()

    static func sluggedHeroAsset(for name: String) -> String? {
        let slug = heroSlug(for: name)
        guard !slug.isEmpty else { return nil }
        let asset = "player-\(slug)-hero"
        heroAssetLookupLock.lock()
        defer { heroAssetLookupLock.unlock() }
        if let cached = heroAssetLookupCache[asset] { return cached }
        let resolved: String? = UIImage(named: asset) != nil ? asset : nil
        heroAssetLookupCache[asset] = resolved
        return resolved
    }

    /// Diacritic-insensitive, lowercase, hyphen-separated ("Félix Auger Aliassime"
    /// and "Felix Auger-Aliassime" both → "felix-auger-aliassime").
    static func heroSlug(for name: String) -> String {
        let folded = name.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US")
        ).lowercased()
        let mapped = folded.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(mapped)
            .split(separator: "-")
            .joined(separator: "-")
    }

    /// Bundled 2026 season W/L — only for the featured top-10 catalog (not custom/API picks).
    var bundledSeasonRecord: (wins: Int, losses: Int)? {
        guard imageName != nil, TennisPlayer.topPlayers.contains(where: { $0.id == id }) else {
            return nil
        }
        return seasonRecord
    }

    /// Prefer bundled featured W/L; custom favorites use Worker-backed `PlayerSeasonRecordCache`.
    /// Retired legends never have a season record — surfaces show `careerRecord` instead.
    var displaySeasonRecord: (wins: Int, losses: Int)? {
        if isRetiredLegend { return nil }
        if let bundled = bundledSeasonRecord { return bundled }
        return PlayerSeasonRecordCache.record(for: id)
    }

    /// Bundled career facts for retired legends (zero API cost — Matchstat
    /// surface-summary is season-only and has no slam-title breakdown).
    /// Verified against ATP/WTA records at retirement (Jul 2026). Keyed by hero
    /// slug so `custom:` IDs and payload spellings resolve without a second map.
    struct LegendCareerStats: Equatable {
        let wins: Int
        let losses: Int
        /// Singles majors: AO, RG, Wimbledon, US Open.
        let australianOpen: Int
        let frenchOpen: Int
        let wimbledon: Int
        let usOpen: Int

        var totalSlams: Int { australianOpen + frenchOpen + wimbledon + usOpen }

        var winPercentage: Int {
            let total = wins + losses
            guard total > 0 else { return 0 }
            return Int((Double(wins) / Double(total) * 100).rounded())
        }

        /// Verbatim career W/L (no locale commas) + win %.
        var recordLine: String {
            "\(wins)-\(losses) · \(winPercentage)%"
        }

        /// Compact slam titles for Lock Screen Stats (AO/RG/WIM/USO order).
        var slamLine: String {
            slamBreakdown
                .map { "\($0.slam.shortCode)\($0.count)" }
                .joined(separator: "  ")
        }

        /// W/L · % · slam split on one line (total GS lives in the leading tile).
        var statsLine: String {
            "\(recordLine) · \(slamLine)"
        }

        var slamBreakdown: [(slam: GrandSlam, count: Int)] {
            [
                (.australianOpen, australianOpen),
                (.frenchOpen, frenchOpen),
                (.wimbledon, wimbledon),
                (.usOpen, usOpen),
            ]
        }
    }

    private static let retiredLegendCareers: [String: LegendCareerStats] = [
        "roger-federer": .init(wins: 1251, losses: 275, australianOpen: 6, frenchOpen: 1, wimbledon: 8, usOpen: 5),
        "rafael-nadal": .init(wins: 1080, losses: 227, australianOpen: 2, frenchOpen: 14, wimbledon: 2, usOpen: 4),
        "pete-sampras": .init(wins: 762, losses: 222, australianOpen: 2, frenchOpen: 0, wimbledon: 7, usOpen: 5),
        "andre-agassi": .init(wins: 870, losses: 274, australianOpen: 4, frenchOpen: 1, wimbledon: 1, usOpen: 2),
        "andy-murray": .init(wins: 739, losses: 262, australianOpen: 0, frenchOpen: 0, wimbledon: 2, usOpen: 1),
        "lleyton-hewitt": .init(wins: 616, losses: 262, australianOpen: 0, frenchOpen: 0, wimbledon: 1, usOpen: 1),
        "andy-roddick": .init(wins: 612, losses: 213, australianOpen: 0, frenchOpen: 0, wimbledon: 0, usOpen: 1),
        "serena-williams": .init(wins: 858, losses: 156, australianOpen: 7, frenchOpen: 3, wimbledon: 7, usOpen: 6),
        "maria-sharapova": .init(wins: 645, losses: 171, australianOpen: 1, frenchOpen: 2, wimbledon: 1, usOpen: 1),
        "ashleigh-barty": .init(wins: 305, losses: 102, australianOpen: 1, frenchOpen: 1, wimbledon: 1, usOpen: 0),
    ]

    var isRetiredLegend: Bool {
        TennisPlayer.retiredLegendCareers[TennisPlayer.heroSlug(for: name)] != nil
    }

    /// Full bundled legend career (W/L + slam titles); `nil` for active players.
    var legendCareer: LegendCareerStats? {
        TennisPlayer.retiredLegendCareers[TennisPlayer.heroSlug(for: name)]
    }

    /// Career singles W/L for retired legends (bundled; `nil` for active players).
    var careerRecord: (wins: Int, losses: Int)? {
        guard let legend = legendCareer else { return nil }
        return (legend.wins, legend.losses)
    }

    /// Bundled 2026 season W/L through current tour stop (featured catalog only).
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
        "Casper Ruud": "rh16", // r0dg is Holger Rune — verified via atptour.com profile URLs Jul 2026
        "Andrey Rublev": "re44",
        "Stefanos Tsitsipas": "te51",
        "Tommy Paul": "pl56",
        "Grigor Dimitrov": "d875",
        "Frances Tiafoe": "td51",
        "Holger Rune": "r0dg",
        "Sebastian Korda": "kb05",
        "Alex de Minaur": "dh58",
        "Felix Auger-Aliassime": "ag37",
        "Felix Auger Aliassime": "ag37",
        "Lorenzo Musetti": "m0ej",
        "Matteo Berrettini": "bk40",
        // Inactive / unranked fan favorites — Worker tries name-slug photo + CDN.
        "Nick Kyrgios": "ke17",
        "Rafael Nadal": "n409",
        "Roger Federer": "f324",
        "Andy Murray": "mc10",
        "Stan Wawrinka": "w367",
        "Gael Monfils": "mc65",
    ]

    /// RapidAPI numeric ids for bundled search-catalog players (dev-time lookup).
    /// Used as a zero-cost fallback for photo fetch when live lookup is rate-limited.
    private static let atpApiIds: [String: Int] = [
        "Novak Djokovic": 5992,
        "Jannik Sinner": 47275,
        "Carlos Alcaraz": 68074,
        "Daniil Medvedev": 22807,
        "Alexander Zverev": 24008,
        "Taylor Fritz": 29932,
        "Ben Shelton": 87562,
        "Hubert Hurkacz": 26473,
        "Casper Ruud": 33648,
        "Andrey Rublev": 29372,
        "Stefanos Tsitsipas": 30470,
        "Tommy Paul": 29935,
        "Grigor Dimitrov": 11953, // 28064 was a doubles pairing — verified via profile endpoint Jul 2026

        "Frances Tiafoe": 29939,
        "Holger Rune": 69471,
        "Sebastian Korda": 42451,
        "Alex de Minaur": 39309,
        "Felix Auger-Aliassime": 40434,
        "Felix Auger Aliassime": 40434,
        "Lorenzo Musetti": 63572,
        "Matteo Berrettini": 29812,
    ]

    static func bundledApiId(for name: String, tour: TourPreference) -> Int? {
        guard tour == .atp else { return nil }
        let folded = fold(name)
        if let exact = atpApiIds[name] { return exact }
        return atpApiIds.first { fold($0.key) == folded }?.value
    }

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
        Entry(name: "Nick Kyrgios", tour: .atp),
        Entry(name: "Rafael Nadal", tour: .atp),
        Entry(name: "Roger Federer", tour: .atp),
        Entry(name: "Andy Murray", tour: .atp),
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
        case .australianOpen: 0x5BB8E8 // light sky blue
        case .frenchOpen: 0xE35205 // clay orange
        case .wimbledon: 0x5C2D91 // royal purple (paired with green highlight)
        case .usOpen: 0x0C2340 // night blue
        }
    }

    /// Secondary brand tint (AO white, USO yellow, RG warm clay, Wimbledon green).
    var highlightColor: UInt {
        switch self {
        case .australianOpen: 0xF5FBFF
        case .frenchOpen: 0xFF8A3D
        case .wimbledon: 0x006633
        case .usOpen: 0xFFD200
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

    /// Lock Screen–safe slam code (fits accessory circular/rectangular).
    var shortCode: String {
        switch self {
        case .australianOpen: "AO"
        case .frenchOpen: "RG"
        case .wimbledon: "WIM"
        case .usOpen: "USO"
        }
    }

    /// Lock Screen badge title — readable slam name (not AO/RG codes).
    var lockDisplayName: String {
        switch self {
        case .australianOpen: "AUS OPEN"
        case .frenchOpen: "ROLAND GARROS"
        case .wimbledon: "WIMBLEDON"
        case .usOpen: "US OPEN"
        }
    }

    /// Short city label for Lock Screen copy (avoids truncation).
    var cityShort: String {
        switch self {
        case .australianOpen: "Melbourne"
        case .frenchOpen: "Paris"
        case .wimbledon: "London"
        case .usOpen: "NYC"
        }
    }
}
