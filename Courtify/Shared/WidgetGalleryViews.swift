import SwiftUI
import UIKit

// MARK: - Favorite player (free, bundled)

struct FavoritePlayerWidgetView: View {
    let player: TennisPlayer?
    var widgetID: String = "favorite"
    @State private var colorTick = 0

    private var rankLabel: String {
        guard let ranking = player?.ranking, ranking > 0 else { return "—" }
        switch ranking {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(ranking)th"
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetColorStyle.gradient(for: widgetID)
                .id(colorTick)

            if let player {
                FavoritePlayerHeroImage(player: player)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(player?.tour.rawValue ?? "ATP")
                    .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)

                Text(player?.name ?? "Pick a player")
                    .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                if let record = player?.bundledSeasonRecord {
                    Text("\(record.wins)-\(record.losses) season")
                        .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                } else if player?.isCustom == true {
                    Text("Season —")
                        .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text(rankLabel)
                    .font(WidgetTheme.roundedFont(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: 108, alignment: .leading)
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }
}

struct FavoritePlayerHeroImage: View {
    let player: TennisPlayer

    var body: some View {
        Group {
            if let bundled = player.imageName {
                Image("\(bundled)-hero")
                    .resizable()
                    .scaledToFit()
            } else if PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .hero),
                      let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: .hero),
                      let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else if PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .head),
                      let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: .head),
                      let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: player.tour == .wta
                      ? "figure.dress.line.vertical.figure"
                      : "figure.tennis")
                    .font(.system(size: 78, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.26))
                    .symbolRenderingMode(.monochrome)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.leading, 88)
        .offset(x: 8, y: 8)
        .opacity(0.95)
        .allowsHitTesting(false)
    }
}

// MARK: - Tournament widgets (bundled calendar)

struct NextTournamentSmallView: View {
    let tour: TourPreference

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack(alignment: .topLeading) {
            widgetSurfaceGradient(for: event)
            VStack(alignment: .leading, spacing: 4) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(WidgetTheme.roundedFont(.caption2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(event.dateRangeLabel)
                        .font(WidgetTheme.roundedFont(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)

                    Text(event.tier.rawValue)
                        .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    let countdown = TournamentCalendar.countdown(to: event)
                    Text("\(countdown.days) days, \(countdown.hours) hr")
                        .font(WidgetTheme.roundedFont(.footnote, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)
                } else {
                    Text("Season complete")
                        .font(WidgetTheme.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
    }
}

struct TournamentCountdownView: View {
    let tour: TourPreference

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack {
            widgetSurfaceGradient(for: event)

            if let imageName = event?.heroImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, -30)
                    .opacity(0.18)
            }

            VStack(spacing: 4) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(event.dateRangeLabel)
                        .font(WidgetTheme.roundedFont(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    let countdown = TournamentCalendar.countdown(to: event)
                    Text("\(countdown.days) DAYS, \(countdown.hours) HR")
                        .font(WidgetTheme.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)

                    Text("\(event.name) 2026")
                        .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("Season complete")
                        .font(WidgetTheme.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
    }
}

struct NextTournamentLargeView: View {
    let tour: TourPreference

    private var upcoming: [TournamentEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return TournamentCalendar.events(for: tour)
            .filter { $0.endDate >= today }
    }

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack(alignment: .topLeading) {
            widgetSurfaceGradient(for: event)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let event {
                        Text("\(event.shortName) · \(event.location.uppercased())")
                            .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)

                        Text(event.dateRangeLabel)
                            .font(WidgetTheme.roundedFont(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        Text("2026 · \(event.surface)")
                            .font(WidgetTheme.roundedFont(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        let countdown = TournamentCalendar.countdown(to: event)
                        HStack(spacing: 12) {
                            widgetCountdownCell(String(format: "%02d", countdown.days), unit: "DAYS")
                            widgetCountdownCell(String(format: "%02d", countdown.hours), unit: "HOURS")
                            widgetCountdownCell(String(format: "%02d", countdown.minutes), unit: "MIN")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Text("COMING UP")
                        .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))

                    ForEach(upcoming.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Text(item.listDateLabel)
                                .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                                .foregroundStyle(WidgetTheme.opticYellow)
                                .frame(width: 44, alignment: .leading)
                            Text(item.name)
                                .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: 150, alignment: .leading)
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
    }
}

struct SeasonCalendarView: View {
    let tour: TourPreference

    private var events: [TournamentEvent] {
        TournamentCalendar.events(for: tour)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x11221A), WidgetTheme.midnightGreen],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Text("2026 \(tour.rawValue) CALENDAR")
                    .font(WidgetTheme.roundedFont(.footnote, weight: .bold))
                    .foregroundStyle(.white)

                let midpoint = (events.count + 1) / 2
                HStack(alignment: .top, spacing: 14) {
                    widgetCalendarColumn(Array(events.prefix(midpoint)))
                    widgetCalendarColumn(Array(events.dropFirst(midpoint)))
                }
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
    }

    private func widgetCalendarColumn(_ column: [TournamentEvent]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(column) { event in
                HStack(spacing: 6) {
                    Text(event.listDateLabel)
                        .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 46, alignment: .leading)

                    if !event.isUpcoming {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(WidgetTheme.courtGreen)
                    }

                    Text(event.name)
                        .font(WidgetTheme.roundedFont(.caption2, weight: event.tier == .grandSlam ? .bold : .medium))
                        .foregroundStyle(event.tier == .grandSlam ? .white : .white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Rankings widgets

struct RankingsWidgetView: View {
    let tour: TourPreference
    let entries: [WidgetRankingEntry]
    let limit: Int
    var showsRefreshHint = false
    var widgetID: String = "atp-medium"
    @State private var colorTick = 0

    var body: some View {
        ZStack {
            WidgetColorStyle.gradient(
                for: widgetID,
                fallbackAccent: tour == .atp ? Color(hex: 0x0C2340) : Color(hex: 0x3D1E52),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .id(colorTick)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(tour.rawValue) TOP \(limit)")
                    .font(WidgetTheme.roundedFont(.caption, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(height: 26, alignment: .topLeading)

                if entries.isEmpty {
                    Spacer()
                    widgetEmptyStateLabel(showsRefreshHint: showsRefreshHint, fallback: "Open Courtify to load rankings")
                    Spacer()
                } else {
                    ForEach(entries.prefix(limit)) { entry in
                        WidgetRankingRow(entry: entry, showsCountry: false)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .padding(WidgetTheme.contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }
}

struct RankingsLargeWidgetView: View {
    let tour: TourPreference
    let entries: [WidgetRankingEntry]
    var showsRefreshHint = false
    var widgetID: String = "atp-large"
    @State private var colorTick = 0

    var body: some View {
        ZStack {
            WidgetColorStyle.gradient(
                for: widgetID,
                fallbackAccent: tour == .atp ? Color(hex: 0x0C2340) : Color(hex: 0x3D1E52),
                startPoint: .top,
                endPoint: .bottom
            )
            .id(colorTick)

            VStack(spacing: 10) {
                Text("2026 \(tour.rawValue) RANKINGS")
                    .font(WidgetTheme.roundedFont(.footnote, weight: .bold))
                    .foregroundStyle(.white)

                if entries.isEmpty {
                    Spacer()
                    widgetEmptyStateLabel(showsRefreshHint: showsRefreshHint, fallback: "Open Courtify to load rankings")
                    Spacer()
                } else {
                    let top10 = Array(entries.prefix(10))
                    let midpoint = min(5, top10.count)
                    HStack(alignment: .top, spacing: 16) {
                        widgetRankingColumn(Array(top10.prefix(midpoint)))
                        widgetRankingColumn(Array(top10.dropFirst(midpoint)))
                    }
                }
            }
            .padding(WidgetTheme.contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }

    private func widgetRankingColumn(_ column: [WidgetRankingEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(column) { entry in
                WidgetRankingRow(entry: entry)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WidgetRankingRow: View {
    let entry: WidgetRankingEntry
    var showsCountry = true

    var body: some View {
        HStack(spacing: 8) {
            Text("\(entry.rank ?? 0)")
                .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.player.name)
                    .font(WidgetTheme.roundedFont(.caption2, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if showsCountry, let country = entry.player.country {
                    Text(country)
                        .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 4)

            if let points = entry.points {
                Text("\(points)")
                    .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
            }
        }
    }
}

// MARK: - Live widgets

struct LiveScoresWidgetView: View {
    let match: WidgetLiveMatch?
    var showsRefreshHint = false
    var widgetID: String = "live"
    @State private var colorTick = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetColorStyle.gradient(
                for: widgetID,
                fallbackAccent: Color(hex: 0x143D2B),
                startPoint: .top,
                endPoint: .bottom
            )
            .id(colorTick)

            if let match {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(WidgetTheme.opticYellow)
                            .frame(width: 6, height: 6)
                        Text("LIVE · \(match.tour)")
                            .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                            .foregroundStyle(WidgetTheme.opticYellow)
                            .lineLimit(1)
                    }

                    if let tournament = match.tournament {
                        Text(tournament)
                            .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(match.player1.name)
                        .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(match.player2.name)
                        .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let score = match.score {
                        Text(score)
                            .font(WidgetTheme.roundedFont(.footnote, weight: .bold))
                            .foregroundStyle(WidgetTheme.opticYellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(WidgetTheme.contentInset)
            } else {
                VStack(spacing: 6) {
                    Text("No live matches")
                        .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    widgetEmptyStateLabel(showsRefreshHint: showsRefreshHint, fallback: "Open Courtify to refresh")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }
}

struct OrderOfPlayListView: View {
    let matches: [WidgetUpcomingMatch]
    var showsRefreshHint = false
    var widgetID: String = "order"
    @State private var colorTick = 0

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetColorStyle.gradient(
                for: widgetID,
                fallbackAccent: Color(hex: 0x0C2340),
                startPoint: .leading,
                endPoint: .bottomTrailing
            )
            .id(colorTick)

            VStack(alignment: .leading, spacing: 12) {
                Text("ORDER OF PLAY")
                    .font(WidgetTheme.roundedFont(.footnote, weight: .bold))
                    .foregroundStyle(.white)

                if matches.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("No upcoming matches")
                                .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            widgetEmptyStateLabel(showsRefreshHint: showsRefreshHint, fallback: "Open Courtify to refresh")
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(matches.prefix(6), id: \.displayID) { match in
                        orderRow(match)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(WidgetTheme.contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }

    private func orderRow(_ match: WidgetUpcomingMatch) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(match.court ?? match.tournament ?? match.tour)
                    .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
                    .lineLimit(1)
                if let startTime = match.startTime {
                    Text(Self.timeFormatter.string(from: startTime))
                        .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 64, alignment: .leading)

            Text(match.player1.name)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("vs")
                .foregroundStyle(.white.opacity(0.45))
            Text(match.player2.name)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .font(WidgetTheme.roundedFont(.caption2, weight: .semibold))
        .foregroundStyle(.white.opacity(0.9))
        .frame(maxHeight: .infinity)
    }
}

struct WidgetRefreshHintLabel: View {
    var body: some View {
        Text("Pull down to refresh")
            .font(WidgetTheme.roundedFont(.caption2))
            .foregroundStyle(.white.opacity(0.55))
    }
}

// MARK: - Helpers

@ViewBuilder
func widgetEmptyStateLabel(showsRefreshHint: Bool, fallback: String) -> some View {
    if showsRefreshHint {
        WidgetRefreshHintLabel()
    } else {
        Text(fallback)
            .font(WidgetTheme.roundedFont(.caption2))
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
    }
}

func rankingsGradient(for tour: TourPreference, large: Bool) -> LinearGradient {
    LinearGradient(
        colors: [tour == .atp ? Color(hex: 0x0C2340) : Color(hex: 0x3D1E52), WidgetTheme.midnightGreen],
        startPoint: large ? .top : .topLeading,
        endPoint: large ? .bottom : .bottomTrailing
    )
}

func widgetSurfaceGradient(for event: TournamentEvent?) -> LinearGradient {
    let accent: UInt
    switch event?.surface {
    case "Clay": accent = 0xE35205
    case "Grass": accent = 0x006633
    case "Hard": accent = 0x0085CA
    default: accent = 0x00703C
    }
    return LinearGradient(
        colors: [Color(hex: accent), WidgetTheme.midnightGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private func widgetCountdownCell(_ value: String, unit: String) -> some View {
    VStack(spacing: 2) {
        Text(value)
            .font(WidgetTheme.roundedFont(size: 24, weight: .bold))
            .foregroundStyle(WidgetTheme.opticYellow)
        Text(unit)
            .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
    }
}
