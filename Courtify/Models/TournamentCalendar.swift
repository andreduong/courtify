import Foundation

enum TournamentTier: String {
    case grandSlam = "Grand Slam"
    case masters1000 = "Masters 1000"
}

struct TournamentEvent: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let location: String
    let tour: TourPreference
    let tier: TournamentTier
    let startDate: Date
    let endDate: Date
    let surface: String
    let heroImageName: String?

    var isUpcoming: Bool {
        endDate >= Calendar.current.startOfDay(for: Date())
    }

    var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMM"
        let startDay = formatter.string(from: startDate).uppercased()
        let endDay = formatter.string(from: endDate)
        let month = monthFormatter.string(from: startDate).uppercased()
        if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .month) {
            return "\(startDay)-\(endDay) \(month)"
        }
        let endMonth = monthFormatter.string(from: endDate).uppercased()
        return "\(startDay) \(month)-\(endDay) \(endMonth)"
    }

    var listDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: startDate).uppercased()
    }
}

enum TournamentCalendar {
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Bundled 2026 ATP/WTA Grand Slams and Masters 1000 schedule (zero API cost).
    static let events2026: [TournamentEvent] = [
        // Grand Slams
        TournamentEvent(id: "gs-ao-atp", name: "Australian Open", shortName: "AO", location: "Melbourne", tour: .atp, tier: .grandSlam, startDate: date(2026, 1, 18), endDate: date(2026, 1, 31), surface: "Hard", heroImageName: "slam-australian-open"),
        TournamentEvent(id: "gs-ao-wta", name: "Australian Open", shortName: "AO", location: "Melbourne", tour: .wta, tier: .grandSlam, startDate: date(2026, 1, 18), endDate: date(2026, 1, 31), surface: "Hard", heroImageName: "slam-australian-open"),
        TournamentEvent(id: "gs-rg-atp", name: "French Open", shortName: "RG", location: "Paris", tour: .atp, tier: .grandSlam, startDate: date(2026, 5, 24), endDate: date(2026, 6, 7), surface: "Clay", heroImageName: "slam-french-open"),
        TournamentEvent(id: "gs-rg-wta", name: "French Open", shortName: "RG", location: "Paris", tour: .wta, tier: .grandSlam, startDate: date(2026, 5, 24), endDate: date(2026, 6, 7), surface: "Clay", heroImageName: "slam-french-open"),
        TournamentEvent(id: "gs-wim-atp", name: "Wimbledon", shortName: "WIM", location: "London", tour: .atp, tier: .grandSlam, startDate: date(2026, 6, 29), endDate: date(2026, 7, 12), surface: "Grass", heroImageName: "slam-wimbledon"),
        TournamentEvent(id: "gs-wim-wta", name: "Wimbledon", shortName: "WIM", location: "London", tour: .wta, tier: .grandSlam, startDate: date(2026, 6, 29), endDate: date(2026, 7, 12), surface: "Grass", heroImageName: "slam-wimbledon"),
        TournamentEvent(id: "gs-uso-atp", name: "US Open", shortName: "USO", location: "New York", tour: .atp, tier: .grandSlam, startDate: date(2026, 8, 30), endDate: date(2026, 9, 13), surface: "Hard", heroImageName: "slam-us-open"),
        TournamentEvent(id: "gs-uso-wta", name: "US Open", shortName: "USO", location: "New York", tour: .wta, tier: .grandSlam, startDate: date(2026, 8, 30), endDate: date(2026, 9, 13), surface: "Hard", heroImageName: "slam-us-open"),

        // Masters 1000 — ATP
        TournamentEvent(id: "m1000-iw-atp", name: "Indian Wells", shortName: "IW", location: "California", tour: .atp, tier: .masters1000, startDate: date(2026, 3, 4), endDate: date(2026, 3, 15), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-mia-atp", name: "Miami Open", shortName: "MIA", location: "Miami", tour: .atp, tier: .masters1000, startDate: date(2026, 3, 18), endDate: date(2026, 3, 29), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-mc-atp", name: "Monte-Carlo Masters", shortName: "MC", location: "Monte Carlo", tour: .atp, tier: .masters1000, startDate: date(2026, 4, 6), endDate: date(2026, 4, 12), surface: "Clay", heroImageName: nil),
        TournamentEvent(id: "m1000-mad-atp", name: "Madrid Open", shortName: "MAD", location: "Madrid", tour: .atp, tier: .masters1000, startDate: date(2026, 4, 22), endDate: date(2026, 5, 3), surface: "Clay", heroImageName: nil),
        TournamentEvent(id: "m1000-rom-atp", name: "Italian Open", shortName: "ROM", location: "Rome", tour: .atp, tier: .masters1000, startDate: date(2026, 5, 7), endDate: date(2026, 5, 17), surface: "Clay", heroImageName: nil),
        TournamentEvent(id: "m1000-can-atp", name: "Canadian Open", shortName: "CAN", location: "Toronto", tour: .atp, tier: .masters1000, startDate: date(2026, 8, 3), endDate: date(2026, 8, 16), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-cin-atp", name: "Cincinnati Open", shortName: "CIN", location: "Cincinnati", tour: .atp, tier: .masters1000, startDate: date(2026, 8, 17), endDate: date(2026, 8, 30), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-sha-atp", name: "Shanghai Masters", shortName: "SHA", location: "Shanghai", tour: .atp, tier: .masters1000, startDate: date(2026, 10, 4), endDate: date(2026, 10, 18), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-par-atp", name: "Paris Masters", shortName: "PAR", location: "Paris", tour: .atp, tier: .masters1000, startDate: date(2026, 10, 28), endDate: date(2026, 11, 8), surface: "Hard", heroImageName: nil),

        // Masters 1000 — WTA
        TournamentEvent(id: "m1000-iw-wta", name: "Indian Wells", shortName: "IW", location: "California", tour: .wta, tier: .masters1000, startDate: date(2026, 3, 4), endDate: date(2026, 3, 15), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-mia-wta", name: "Miami Open", shortName: "MIA", location: "Miami", tour: .wta, tier: .masters1000, startDate: date(2026, 3, 18), endDate: date(2026, 3, 29), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-mad-wta", name: "Madrid Open", shortName: "MAD", location: "Madrid", tour: .wta, tier: .masters1000, startDate: date(2026, 4, 22), endDate: date(2026, 5, 3), surface: "Clay", heroImageName: nil),
        TournamentEvent(id: "m1000-rom-wta", name: "Italian Open", shortName: "ROM", location: "Rome", tour: .wta, tier: .masters1000, startDate: date(2026, 5, 7), endDate: date(2026, 5, 17), surface: "Clay", heroImageName: nil),
        TournamentEvent(id: "m1000-can-wta", name: "Canadian Open", shortName: "CAN", location: "Montreal", tour: .wta, tier: .masters1000, startDate: date(2026, 8, 3), endDate: date(2026, 8, 16), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-cin-wta", name: "Cincinnati Open", shortName: "CIN", location: "Cincinnati", tour: .wta, tier: .masters1000, startDate: date(2026, 8, 17), endDate: date(2026, 8, 30), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-bj-wta", name: "China Open", shortName: "BJ", location: "Beijing", tour: .wta, tier: .masters1000, startDate: date(2026, 9, 28), endDate: date(2026, 10, 11), surface: "Hard", heroImageName: nil),
        TournamentEvent(id: "m1000-wu-wta", name: "Wuhan Open", shortName: "WU", location: "Wuhan", tour: .wta, tier: .masters1000, startDate: date(2026, 10, 12), endDate: date(2026, 10, 18), surface: "Hard", heroImageName: nil),
    ]

    static func events(for tour: TourPreference) -> [TournamentEvent] {
        events2026
            .filter { $0.tour == tour }
            .sorted { $0.startDate < $1.startDate }
    }

    static func nextMajor(for tour: TourPreference) -> TournamentEvent? {
        let today = calendar.startOfDay(for: Date())
        return events(for: tour)
            .filter { $0.endDate >= today }
            .sorted { lhs, rhs in
                if lhs.tier != rhs.tier {
                    return lhs.tier == .grandSlam
                }
                return lhs.startDate < rhs.startDate
            }
            .first
    }

    static func countdown(to event: TournamentEvent) -> (days: Int, hours: Int, minutes: Int) {
        let now = Date()
        let target = event.startDate > now ? event.startDate : event.endDate
        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: target)
        return (
            max(0, components.day ?? 0),
            max(0, components.hour ?? 0),
            max(0, components.minute ?? 0)
        )
    }
}
