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
    let imageURL: URL?
    let ranking: Int

    static let topPlayers: [TennisPlayer] = [
        TennisPlayer(id: "djokovic", name: "Novak Djokovic", tour: .atp, imageURL: URL(string: "https://www.atptour.com/-/media/alias/player-headshot/D643"), ranking: 1),
        TennisPlayer(id: "sinner", name: "Jannik Sinner", tour: .atp, imageURL: URL(string: "https://www.atptour.com/-/media/alias/player-headshot/S0AG"), ranking: 2),
        TennisPlayer(id: "alcaraz", name: "Carlos Alcaraz", tour: .atp, imageURL: URL(string: "https://www.atptour.com/-/media/alias/player-headshot/A0E2"), ranking: 3),
        TennisPlayer(id: "medvedev", name: "Daniil Medvedev", tour: .atp, imageURL: URL(string: "https://www.atptour.com/-/media/alias/player-headshot/MM58"), ranking: 4),
        TennisPlayer(id: "zverev", name: "Alexander Zverev", tour: .atp, imageURL: URL(string: "https://www.atptour.com/-/media/alias/player-headshot/Z355"), ranking: 5),
        TennisPlayer(id: "swiatek", name: "Iga Świątek", tour: .wta, imageURL: nil, ranking: 1),
        TennisPlayer(id: "sabalenka", name: "Aryna Sabalenka", tour: .wta, imageURL: nil, ranking: 2),
        TennisPlayer(id: "gauff", name: "Coco Gauff", tour: .wta, imageURL: nil, ranking: 3),
        TennisPlayer(id: "rybakina", name: "Elena Rybakina", tour: .wta, imageURL: nil, ranking: 4),
        TennisPlayer(id: "pegula", name: "Jessica Pegula", tour: .wta, imageURL: nil, ranking: 5),
    ]
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

    var icon: String {
        switch self {
        case .australianOpen: "sun.max.fill"
        case .frenchOpen: "leaf.fill"
        case .wimbledon: "laurel.leading"
        case .usOpen: "building.2.fill"
        }
    }
}
