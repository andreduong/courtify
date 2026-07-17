import SwiftUI
import UIKit

// MARK: - Favorite player (free, bundled)

struct FavoritePlayerWidgetView: View {
    let player: TennisPlayer?
    var widgetID: String = "favorite"
    @State private var colorTick = 0

    private var rankLabel: String {
        WidgetTheme.ordinalRank(player?.ranking)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetColorStyle.gradient(for: widgetID)
                .id(colorTick)
            WidgetHatchOverlay(opacity: 0.06)

            if let player {
                FavoritePlayerHeroImage(player: player)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(player?.tour.rawValue ?? "ATP")
                    .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
                    .tracking(0.6)

                Text(favoriteDisplayName)
                    .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                if let record = player?.displaySeasonRecord {
                    Text("\(record.wins)–\(record.losses)")
                        .font(WidgetTheme.displayFont(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("SEASON")
                        .font(WidgetTheme.roundedFont(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                } else if player?.isCustom == true {
                    Text("—")
                        .font(WidgetTheme.displayFont(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("SEASON")
                        .font(WidgetTheme.roundedFont(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Text(rankLabel)
                    .font(WidgetTheme.displayFont(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
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

    private var favoriteDisplayName: String {
        guard let player else { return "Pick a player" }
        let parts = player.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts.dropLast().joined(separator: " "))\n\(parts.last!.uppercased())"
        }
        return player.name.uppercased()
    }
}

/// Medium favorite — F1 “driver card”: rank + points-style W/L + stacked stats + hero.
struct FavoritePlayerMediumWidgetView: View {
    let player: TennisPlayer?
    var widgetID: String = "favorite-medium"
    @State private var colorTick = 0

    var body: some View {
        ZStack {
            WidgetColorStyle.gradient(
                for: widgetID,
                fallbackAccent: WidgetTheme.emeraldGreen,
                startPoint: .leading,
                endPoint: .trailing
            )
            .id(colorTick)
            WidgetHatchOverlay(opacity: 0.05)

            if let player {
                FavoritePlayerHeroImage(player: player)
                    .padding(.leading, 120)
            }

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(player?.tour.rawValue ?? "ATP")
                            .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                            .foregroundStyle(WidgetTheme.opticYellow)
                        Text(player?.name.uppercased() ?? "PICK A PLAYER")
                            .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 0)

                    Text(WidgetTheme.ordinalRank(player?.ranking))
                        .font(WidgetTheme.displayFont(size: 42, weight: .heavy))
                        .foregroundStyle(.white)

                    if let record = player?.displaySeasonRecord {
                        Text("\(record.wins)–\(record.losses) W–L")
                            .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let record = player?.displaySeasonRecord {
                    VStack(alignment: .trailing, spacing: 10) {
                        mediumStat(value: "\(record.wins)", label: "Wins")
                        mediumStat(value: "\(record.losses)", label: "Losses")
                        mediumStat(
                            value: winPct(record),
                            label: "Win %"
                        )
                    }
                    .padding(.trailing, 28)
                    .padding(.top, 28)
                }
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }

    private func mediumStat(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(WidgetTheme.displayFont(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func winPct(_ record: (wins: Int, losses: Int)) -> String {
        let total = record.wins + record.losses
        guard total > 0 else { return "—" }
        return "\(Int((Double(record.wins) / Double(total) * 100).rounded()))%"
    }
}

struct FavoritePlayerHeroImage: View {
    let player: TennisPlayer
    var edge: Edge = .trailing

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
                    .foregroundStyle(.white.opacity(0.22))
                    .symbolRenderingMode(.monochrome)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: edge == .leading ? .bottomLeading : .bottomTrailing
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: edge == .leading ? .bottomLeading : .bottomTrailing
        )
        .padding(edge == .leading ? .trailing : .leading, 88)
        .offset(x: edge == .leading ? -8 : 8, y: 8)
        .opacity(0.97)
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
                        .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .tracking(0.4)

                    Text(event.dateRangeLabel.uppercased())
                        .font(WidgetTheme.displayFont(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.55)
                        .lineLimit(2)

                    Text(event.surface.uppercased())
                        .font(WidgetTheme.roundedFont(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))

                    Spacer(minLength: 0)

                    let countdown = TournamentCalendar.countdown(to: event)
                    Text("\(countdown.days) DAY\(countdown.days == 1 ? "" : "S"), \(countdown.hours) HR")
                        .font(WidgetTheme.displayFont(size: 13, weight: .bold))
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

            // Soft tennis-ball watermark — not a muddy tournament logo
            Image(systemName: "tennisball.fill")
                .font(.system(size: 120, weight: .bold))
                .foregroundStyle(.white.opacity(0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(x: 28, y: 10)
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .tracking(0.6)

                    Text(event.dateRangeLabel.uppercased())
                        .font(WidgetTheme.displayFont(size: 26, weight: .heavy))
                        .foregroundStyle(.white)

                    let countdown = TournamentCalendar.countdown(to: event)
                    HStack(spacing: 18) {
                        widgetCountdownCell("\(countdown.days)", unit: "DAYS")
                        widgetCountdownCell(String(format: "%02d", countdown.hours), unit: "HOURS")
                    }
                    .padding(.top, 2)

                    Text("\(event.name.uppercased()) 2026")
                        .font(WidgetTheme.roundedFont(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.0)
                        .padding(.top, 2)
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

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    if let event {
                        Text("\(event.shortName) · \(event.location.uppercased())")
                            .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .tracking(0.4)

                        Text(event.dateRangeLabel.uppercased())
                            .font(WidgetTheme.displayFont(size: 32, weight: .heavy))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        Text("2026 · \(event.surface.uppercased())")
                            .font(WidgetTheme.roundedFont(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))

                        Spacer(minLength: 0)

                        let countdown = TournamentCalendar.countdown(to: event)
                        HStack(spacing: 14) {
                            widgetCountdownCell(String(format: "%02d", countdown.days), unit: "DAYS")
                            widgetCountdownCell(String(format: "%02d", countdown.hours), unit: "HOURS")
                            widgetCountdownCell(String(format: "%02d", countdown.minutes), unit: "MIN")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("COMING UP")
                        .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(0.6)

                    ForEach(upcoming.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Text(item.listDateLabel)
                                .font(WidgetTheme.roundedFont(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(WidgetTheme.roundedFont(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                                Text(item.surface)
                                    .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                                    .foregroundStyle(WidgetTheme.surfaceAccent(for: item.surface).opacity(0.9))
                            }

                            Spacer(minLength: 0)

                            WidgetAccentBar(color: WidgetTheme.surfaceAccent(for: item.surface), width: 2.5)
                                .frame(height: 22)
                        }
                    }
                }
                .frame(width: 158, alignment: .leading)
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
            WidgetAtmosphere(accent: Color(hex: 0x143D2B), glowOpacity: 0.35, hatchOpacity: 0.05)

            VStack(spacing: 10) {
                Text("2026 \(tour.rawValue) CALENDAR")
                    .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(0.8)

                let midpoint = (events.count + 1) / 2
                HStack(alignment: .top, spacing: 12) {
                    widgetCalendarColumn(Array(events.prefix(midpoint)))
                    widgetCalendarColumn(Array(events.dropFirst(midpoint)))
                }
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas()
    }

    private func widgetCalendarColumn(_ column: [TournamentEvent]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(column) { event in
                HStack(spacing: 6) {
                    Text(event.listDateLabel)
                        .font(WidgetTheme.roundedFont(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .frame(width: 48, alignment: .leading)

                    if !event.isUpcoming {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(WidgetTheme.courtGreen)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.name)
                            .font(WidgetTheme.roundedFont(size: 11, weight: event.tier == .grandSlam ? .bold : .medium))
                            .foregroundStyle(event.tier == .grandSlam ? .white : .white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(event.shortName) · \(event.location)")
                            .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    WidgetAccentBar(color: WidgetTheme.surfaceAccent(for: event.surface), width: 2.5)
                        .frame(height: 18)
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

    private var leader: WidgetRankingEntry? { entries.first }
    private var leaderPlayer: TennisPlayer? {
        guard let leader else { return nil }
        return TennisPlayer.topPlayers.first {
            $0.tour == tour && namesMatch($0.name, leader.player.name)
        }
    }

    var body: some View {
        ZStack {
            WidgetColorStyle.gradient(
                for: widgetID,
                fallbackAccent: tour == .atp ? Color(hex: 0x0C3A5C) : Color(hex: 0x5A2D78),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .id(colorTick)
            WidgetHatchOverlay(opacity: 0.05)

            if let leaderPlayer {
                FavoritePlayerHeroImage(player: leaderPlayer, edge: .leading)
                    .padding(.trailing, 150)
                    .opacity(0.88)
            }

            HStack(alignment: .top, spacing: 10) {
                // Leader spotlight
                VStack(alignment: .leading, spacing: 4) {
                    Text(tour.rawValue)
                        .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)

                    Text(leader?.player.name.uppercased() ?? "STANDINGS")
                        .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 0)

                    Text(WidgetTheme.ordinalRank(leader?.rank))
                        .font(WidgetTheme.displayFont(size: 34, weight: .heavy))
                        .foregroundStyle(.white)

                    if let points = leader?.points {
                        Text("\(points) pts")
                            .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 110, alignment: .leading)

                // Top list
                VStack(alignment: .leading, spacing: 0) {
                    if entries.isEmpty {
                        Spacer()
                        widgetEmptyStateLabel(showsRefreshHint: showsRefreshHint, fallback: "Open Courtify to load rankings")
                        Spacer()
                    } else {
                        ForEach(entries.prefix(limit)) { entry in
                            WidgetRankingRow(
                                entry: entry,
                                showsCountry: true,
                                accent: WidgetTheme.tourAccent(for: tour)
                            )
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func namesMatch(_ a: String, _ b: String) -> Bool {
        let na = a.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let nb = b.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let lastA = na.split(separator: " ").last.map(String.init) ?? na
        let lastB = nb.split(separator: " ").last.map(String.init) ?? nb
        return lastA == lastB || na.contains(lastB) || nb.contains(lastA)
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
                fallbackAccent: tour == .atp ? Color(hex: 0x0C3A5C) : Color(hex: 0x5A2D78),
                startPoint: .top,
                endPoint: .bottom
            )
            .id(colorTick)
            WidgetHatchOverlay(opacity: 0.05)

            VStack(spacing: 10) {
                Text("2026 \(tour.rawValue) RANKINGS")
                    .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(0.8)

                if entries.isEmpty {
                    Spacer()
                    widgetEmptyStateLabel(showsRefreshHint: showsRefreshHint, fallback: "Open Courtify to load rankings")
                    Spacer()
                } else {
                    let top10 = Array(entries.prefix(10))
                    let midpoint = min(5, top10.count)
                    HStack(alignment: .top, spacing: 14) {
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
                WidgetRankingRow(
                    entry: entry,
                    accent: WidgetTheme.tourAccent(for: tour)
                )
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WidgetRankingRow: View {
    let entry: WidgetRankingEntry
    var showsCountry = true
    var accent: Color = WidgetTheme.opticYellow

    var body: some View {
        HStack(spacing: 7) {
            Text("\(entry.rank ?? 0)")
                .font(WidgetTheme.displayFont(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.player.name)
                    .font(WidgetTheme.roundedFont(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if showsCountry, let country = entry.player.country {
                    Text(country)
                        .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 4)

            if let points = entry.points {
                Text("\(points)")
                    .font(WidgetTheme.displayFont(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            WidgetAccentBar(color: accent, width: 2.5)
                .frame(height: 16)
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
                fallbackAccent: Color(hex: 0x1A5C3A),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .id(colorTick)
            WidgetHatchOverlay(opacity: 0.06)

            if let match {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE · \(match.tour)")
                            .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                            .foregroundStyle(WidgetTheme.opticYellow)
                            .lineLimit(1)
                            .tracking(0.4)
                    }

                    if let tournament = match.tournament {
                        Text(tournament.uppercased())
                            .font(WidgetTheme.roundedFont(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text(match.player1.name)
                        .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(match.player2.name)
                        .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if let score = match.score {
                        Text(score)
                            .font(WidgetTheme.displayFont(size: 18, weight: .heavy))
                            .foregroundStyle(WidgetTheme.opticYellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .padding(.top, 2)
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
                fallbackAccent: Color(hex: 0x0C3A5C),
                startPoint: .leading,
                endPoint: .bottomTrailing
            )
            .id(colorTick)
            WidgetHatchOverlay(opacity: 0.05)

            VStack(alignment: .leading, spacing: 10) {
                Text("ORDER OF PLAY")
                    .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(0.8)

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
            VStack(alignment: .leading, spacing: 1) {
                Text(match.court ?? match.tournament ?? match.tour)
                    .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
                    .lineLimit(1)
                if let startTime = match.startTime {
                    Text(Self.timeFormatter.string(from: startTime))
                        .font(WidgetTheme.roundedFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(width: 64, alignment: .leading)

            Text(match.player1.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("vs")
                .foregroundStyle(.white.opacity(0.4))
            Text(match.player2.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            WidgetAccentBar(color: WidgetTheme.courtGreen, width: 2.5)
                .frame(height: 18)
        }
        .font(WidgetTheme.roundedFont(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.9))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Lock screen previews (gallery)

struct LockScreenCircularRankView: View {
    let player: TennisPlayer?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: gaugeProgress)
                .stroke(
                    WidgetTheme.opticYellow,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(WidgetTheme.ordinalRank(player?.ranking))
                    .font(WidgetTheme.displayFont(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                Text(shortName)
                    .font(WidgetTheme.roundedFont(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.midnightGreen)
        .courtifyWidgetCanvas()
    }

    private var shortName: String {
        guard let player else { return "—" }
        return player.name.split(separator: " ").last.map(String.init)?.uppercased() ?? player.name
    }

    private var gaugeProgress: CGFloat {
        guard let ranking = player?.ranking, ranking > 0 else { return 0.15 }
        return max(0.12, min(1, 1.0 - CGFloat(ranking - 1) / 20.0))
    }
}

struct LockScreenCircularCountdownView: View {
    let tour: TourPreference

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        let days = event.map { TournamentCalendar.countdown(to: $0).days } ?? 0

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(1, CGFloat(days) / 60.0))
                .stroke(
                    WidgetTheme.surfaceAccent(for: event?.surface),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(days)")
                    .font(WidgetTheme.displayFont(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                Text("DAYS")
                    .font(WidgetTheme.roundedFont(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.midnightGreen)
        .courtifyWidgetCanvas()
    }
}

struct LockScreenRectangularNextView: View {
    let tour: TourPreference

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        HStack(spacing: 10) {
            Image(systemName: "tennisball.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(WidgetTheme.opticYellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    let countdown = TournamentCalendar.countdown(to: event)
                    Text("\(countdown.days)d \(countdown.hours)h")
                        .font(WidgetTheme.displayFont(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    Text("Season done")
                        .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WidgetTheme.midnightGreen)
        .courtifyWidgetCanvas()
    }
}

struct LockScreenRectangularLiveView: View {
    let match: WidgetLiveMatch?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(match == nil ? Color.white.opacity(0.3) : Color.red)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                if let match {
                    Text("\(shortName(match.player1.name)) vs \(shortName(match.player2.name))")
                        .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(match.score ?? "LIVE")
                        .font(WidgetTheme.displayFont(size: 14, weight: .heavy))
                        .foregroundStyle(WidgetTheme.opticYellow)
                        .lineLimit(1)
                } else {
                    Text("No live match")
                        .font(WidgetTheme.roundedFont(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WidgetTheme.midnightGreen)
        .courtifyWidgetCanvas()
    }

    private func shortName(_ name: String) -> String {
        name.split(separator: " ").last.map(String.init) ?? name
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

private func widgetCountdownCell(_ value: String, unit: String) -> some View {
    VStack(spacing: 2) {
        Text(value)
            .font(WidgetTheme.displayFont(size: 28, weight: .heavy))
            .foregroundStyle(WidgetTheme.opticYellow)
        Text(unit)
            .font(WidgetTheme.roundedFont(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.5))
            .tracking(0.8)
    }
}
