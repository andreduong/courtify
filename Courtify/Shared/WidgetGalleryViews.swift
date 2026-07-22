import SwiftUI
import UIKit
import WidgetKit

// MARK: - Favorite player (free, bundled)

struct FavoritePlayerWidgetView: View {
    let player: TennisPlayer?
    var widgetID: String = "favorite"
    /// When set (paywall marquee), bypasses saved WidgetColorStyle for this card.
    var forceAccent: Color? = nil
    @State private var colorTick = 0

    private var rankLabel: String {
        WidgetTheme.ordinalRank(player?.ranking)
    }

    private var resolvedAccent: Color {
        forceAccent ?? WidgetColorStyle.config(for: widgetID).resolvedAccent
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let forceAccent {
                    WidgetColorStyle.gradient(accent: forceAccent)
                } else {
                    WidgetColorStyle.gradient(for: widgetID)
                }
            }
            .id(colorTick)
            WidgetTextureOverlay(
                texture: WidgetColorStyle.texture(for: widgetID),
                accent: resolvedAccent
            )

            if let player {
                FavoritePlayerHeroImage(player: player)
            }

            VStack(alignment: .leading, spacing: 3) {
                if let player {
                    Text(player.tour == .wta ? "WTA" : "ATP")
                        .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)
                        .tracking(0.6)
                }

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
                        .courtifyMicroLabel()
                } else if player?.isCustom == true {
                    Text("—")
                        .font(WidgetTheme.displayFont(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("SEASON")
                        .courtifyMicroLabel()
                }

                Text(rankLabel)
                    .font(WidgetTheme.displayFont(size: 36, weight: .heavy))
                    .courtifyScoreboardNumber()
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
            .frame(maxWidth: 108, alignment: .leading)
            .padding(WidgetTheme.contentInsets)
        }
        // Center stamp — clears large rank (leading) and gallery person chrome (trailing)
        .courtifyWidgetCanvas(stamp: .bottomCenter)
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.appAppearanceDidChange)) { _ in
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

/// Medium favorite — F1 “driver card”: copy column + hero column (no stats over torso).
struct FavoritePlayerMediumWidgetView: View {
    let player: TennisPlayer?
    var widgetID: String = "favorite-medium"
    var forceAccent: Color? = nil
    @State private var colorTick = 0

    private var resolvedAccent: Color {
        forceAccent ?? WidgetColorStyle.config(for: widgetID).resolvedAccent
    }

    var body: some View {
        ZStack {
            Group {
                if let forceAccent {
                    WidgetColorStyle.gradient(
                        accent: forceAccent,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    WidgetColorStyle.gradient(
                        for: widgetID,
                        fallbackAccent: WidgetTheme.emeraldGreen,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .id(colorTick)
            WidgetTextureOverlay(
                texture: WidgetColorStyle.texture(for: widgetID),
                accent: resolvedAccent
            )

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    if let player {
                        HStack(spacing: 6) {
                            Text(player.tour == .wta ? "WTA" : "ATP")
                                .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                                .foregroundStyle(WidgetTheme.opticYellow)
                            Text(player.name.uppercased())
                                .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    } else {
                        Text("PICK A PLAYER")
                            .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 0)

                    Text(WidgetTheme.ordinalRank(player?.ranking))
                        .font(WidgetTheme.displayFont(size: 42, weight: .heavy))
                        .courtifyScoreboardNumber()
                        .foregroundStyle(.white)

                    if let record = player?.displaySeasonRecord {
                        Text("\(record.wins)–\(record.losses) W–L")
                            .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))

                        HStack(spacing: 10) {
                            mediumStat(value: "\(record.wins)", label: "Wins")
                            mediumStat(value: "\(record.losses)", label: "Losses")
                            mediumStat(value: winPct(record), label: "Win %")
                        }
                        .padding(.top, 6)
                    } else if player?.isCustom == true {
                        // Keeps the stat column from collapsing into jarring empty space
                        // while the season record syncs (or is unavailable for retirees).
                        HStack(spacing: 10) {
                            mediumStat(value: "—", label: "Wins")
                            mediumStat(value: "—", label: "Losses")
                            mediumStat(value: "—", label: "Win %")
                        }
                        .padding(.top, 6)
                        .opacity(0.55)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)

                ZStack(alignment: .bottomTrailing) {
                    if let player {
                        MediumFavoriteHeroCutout(player: player)
                    }
                }
                .frame(width: 118)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .clipped()
            }
            .padding(WidgetTheme.contentInsets)
        }
        // Center stamp — stats sit leading, hero cutout trailing
        .courtifyWidgetCanvas(stamp: .bottomCenter)
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.appAppearanceDidChange)) { _ in
            colorTick += 1
        }
    }

    private func mediumStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(WidgetTheme.displayFont(size: 15, weight: .heavy))
                .courtifyScoreboardNumber()
                .foregroundStyle(.white)
            Text(label)
                .courtifyMicroLabel()
        }
    }

    private func winPct(_ record: (wins: Int, losses: Int)) -> String {
        let total = record.wins + record.losses
        guard total > 0 else { return "—" }
        return "\(Int((Double(record.wins) / Double(total) * 100).rounded()))%"
    }
}

/// Tight torso for the medium favorite hero column (no 88pt gallery padding).
/// Bundled `-hero` cutouts only; API studio JPEGs render as circles — never rectangles.
private struct MediumFavoriteHeroCutout: View {
    let player: TennisPlayer

    var body: some View {
        Group {
            if let bundled = player.imageName {
                Image("\(bundled)-hero")
                    .resizable()
                    .scaledToFit()
                    .courtifyHeroFadeMask()
            } else if let uiImage = studioHeadshotImage(for: player) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 16)
            } else {
                PlayerSilhouetteView(tour: player.tour, style: .torso, size: 64)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .offset(x: 10, y: 10)
        .allowsHitTesting(false)
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
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: edge == .leading ? .bottomLeading : .bottomTrailing
                    )
                    .courtifyHeroFadeMask()
            } else if let uiImage = studioHeadshotImage(for: player) {
                // Studio plates are not cutouts — circular badge, not a grey rectangle.
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 86, height: 86)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: edge == .leading ? .bottomLeading : .bottomTrailing
                    )
                    .padding(edge == .leading ? .leading : .trailing, 10)
                    .padding(.bottom, 18)
            } else {
                PlayerSilhouetteView(
                    tour: player.tour,
                    style: .torso,
                    size: 78,
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

/// Any cached API JPEG is a studio plate — head preferred; leftover `-hero.jpg` is the same bytes.
private func studioHeadshotImage(for player: TennisPlayer) -> UIImage? {
    if PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .head),
       let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: .head),
       let image = UIImage(contentsOfFile: path) {
        return image
    }
    if PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .hero),
       let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: .hero),
       let image = UIImage(contentsOfFile: path) {
        return image
    }
    return nil
}

// MARK: - Tournament widgets (bundled calendar)

struct NextTournamentSmallView: View {
    let tour: TourPreference
    /// Paywall marquee — force a Grand Slam brand wash regardless of calendar.
    var forceSlam: GrandSlam? = nil
    var widgetID: String = "next-small"
    @State private var colorTick = 0

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack(alignment: .topLeading) {
            WidgetStyledBackground(
                widgetID: widgetID,
                event: event,
                forceSlam: forceSlam
            )
            .id(colorTick)

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
            .padding(WidgetTheme.contentInsets)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }
}

struct TournamentCountdownView: View {
    let tour: TourPreference
    var forceSlam: GrandSlam? = nil
    var widgetID: String = "countdown"
    @State private var colorTick = 0

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack {
            WidgetStyledBackground(
                widgetID: widgetID,
                event: event,
                forceSlam: forceSlam
            )
            .id(colorTick)

            CourtifyTennisBallWatermark()

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
            .padding(WidgetTheme.contentInsets)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }
}

struct NextTournamentLargeView: View {
    let tour: TourPreference
    var forceSlam: GrandSlam? = nil
    var widgetID: String = "next-large"
    @State private var colorTick = 0

    private var upcoming: [TournamentEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return TournamentCalendar.events(for: tour)
            .filter { $0.endDate >= today }
    }

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack(alignment: .topLeading) {
            WidgetStyledBackground(
                widgetID: widgetID,
                event: event,
                forceSlam: forceSlam
            )
            .id(colorTick)

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
            .padding(WidgetTheme.contentInsets)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
    }
}

struct SeasonCalendarView: View {
    let tour: TourPreference
    var forceSlam: GrandSlam? = nil
    var widgetID: String = "calendar"
    @State private var colorTick = 0

    private var events: [TournamentEvent] {
        TournamentCalendar.events(for: tour)
    }

    var body: some View {
        ZStack {
            WidgetStyledBackground(
                widgetID: widgetID,
                forceSlam: forceSlam,
                usesCalendarTournamentLook: true
            )
            .id(colorTick)

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
            .padding(WidgetTheme.contentInsets)
        }
        .courtifyWidgetCanvas()
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { note in
            guard (note.object as? String) == widgetID || note.object == nil else { return }
            colorTick += 1
        }
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
    var forceAccent: Color? = nil
    @State private var colorTick = 0

    private var leader: WidgetRankingEntry? { entries.first }

    private var resolvedAccent: Color {
        forceAccent
            ?? WidgetColorStyle.config(for: widgetID).resolvedAccent
    }

    var body: some View {
        ZStack {
            Group {
                if let forceAccent {
                    WidgetColorStyle.gradient(
                        accent: forceAccent,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    WidgetColorStyle.gradient(
                        for: widgetID,
                        fallbackAccent: tour == .atp ? Color(hex: 0x0C3A5C) : Color(hex: 0x5A2D78),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .id(colorTick)
            WidgetTextureOverlay(
                texture: WidgetColorStyle.texture(for: widgetID),
                accent: resolvedAccent
            )

            HStack(alignment: .top, spacing: 12) {
                // Leader spotlight — typography only (no torso under pts / list)
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
                        .font(WidgetTheme.displayFont(size: 36, weight: .heavy))
                        .foregroundStyle(.white)

                    if let points = leader?.points {
                        Text("\(points) pts")
                            .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 118, alignment: .leading)

                // Top list — never under a torso
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
            .padding(WidgetTheme.contentInsets)
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
                fallbackAccent: tour == .atp ? Color(hex: 0x0C3A5C) : Color(hex: 0x5A2D78),
                startPoint: .top,
                endPoint: .bottom
            )
            .id(colorTick)
            WidgetTextureOverlay(
                texture: WidgetColorStyle.texture(for: widgetID),
                accent: WidgetColorStyle.config(for: widgetID).resolvedAccent
            )

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
            .padding(WidgetTheme.contentInsets)
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
    var forceAccent: Color? = nil
    @State private var colorTick = 0

    private var resolvedAccent: Color {
        forceAccent ?? WidgetColorStyle.config(for: widgetID).resolvedAccent
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let forceAccent {
                    WidgetColorStyle.gradient(
                        accent: forceAccent,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    WidgetColorStyle.gradient(
                        for: widgetID,
                        fallbackAccent: Color(hex: 0x121212),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .id(colorTick)
            WidgetTextureOverlay(
                texture: WidgetColorStyle.texture(for: widgetID),
                accent: resolvedAccent
            )

            if let match {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isClassicMatch(match) ? WidgetTheme.opticYellow : Color.red)
                            .frame(width: 5, height: 5)
                        Text(liveBadgeTitle(for: match))
                            .font(WidgetTheme.roundedFont(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .tracking(0.6)
                        Spacer(minLength: 0)
                        if let court = match.court {
                            Text(court.uppercased())
                                .font(WidgetTheme.roundedFont(size: 8, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.35))
                                .lineLimit(1)
                        }
                    }

                    if let tournament = match.tournament {
                        Text(tournament.uppercased())
                            .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .tracking(0.5)
                    }

                    Spacer(minLength: 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.player1.name)
                            .font(WidgetTheme.roundedFont(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(match.player2.name)
                            .font(WidgetTheme.roundedFont(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let score = match.score {
                            Text(score)
                                .font(WidgetTheme.displayFont(size: 17, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        if let game = match.gameScore {
                            Text(game)
                                .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                                .foregroundStyle(WidgetTheme.opticYellow)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(WidgetTheme.contentInsets)
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

    private func isClassicMatch(_ match: WidgetLiveMatch) -> Bool {
        match.status?.uppercased() == "CLASSIC"
    }

    private func liveBadgeTitle(for match: WidgetLiveMatch) -> String {
        if isClassicMatch(match) {
            return "CLASSIC · \(match.tour)"
        }
        return "LIVE · \(match.tour)"
    }
}

struct OrderOfPlayListView: View {
    let matches: [WidgetUpcomingMatch]
    var showsRefreshHint = false
    var widgetID: String = "order"
    var forceAccent: Color? = nil
    @State private var colorTick = 0

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var resolvedAccent: Color {
        forceAccent ?? WidgetColorStyle.config(for: widgetID).resolvedAccent
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let forceAccent {
                    WidgetColorStyle.gradient(
                        accent: forceAccent,
                        startPoint: .leading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    WidgetColorStyle.gradient(
                        for: widgetID,
                        fallbackAccent: Color(hex: GrandSlam.australianOpen.accentColor),
                        startPoint: .leading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .id(colorTick)
            WidgetTextureOverlay(
                texture: WidgetColorStyle.texture(for: widgetID),
                accent: resolvedAccent
            )

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
            .padding(WidgetTheme.contentInsets)
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

// MARK: - Lock Screen (accessory) views

/// Stylized COURTIFY wordmark for locked Premium CTAs (upright — matches “Subscribe to”).
struct CourtifyWordmark: View {
    var size: CGFloat = 14

    var body: some View {
        Text("COURTIFY")
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(.white)
    }
}

/// Gallery-only frosted plate so Lock Screen previews match accessory chrome
/// (`AccessoryWidgetBackground` is empty outside WidgetKit).
struct LockScreenPreviewPlate: View {
    enum ShapeStyle {
        case circular
        case rectangular
    }

    let style: ShapeStyle

    var body: some View {
        Group {
            switch style {
            case .circular:
                Circle()
                    .fill(Color.white.opacity(0.14))
            case .rectangular:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            }
        }
    }
}

/// Showcase data for Lock Screen gallery / WidgetKit previews (Alcaraz + Wimbledon).
enum LockScreenGallerySamples {
    static var player: TennisPlayer {
        WidgetPreviewSamples.favoritePlayer
    }

    static var slam: GrandSlam { .wimbledon }

    static var tour: TourPreference { .atp }

    static var liveMatch: WidgetLiveMatch? {
        WidgetPreviewSamples.galleryLiveMatch
    }
}

struct LockScreenCircularRankView: View {
    let player: TennisPlayer?
    var showsPreviewPlate: Bool = false

    var body: some View {
        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .circular)
            }
            Gauge(value: gaugeProgress) {
                Image(systemName: "trophy.fill")
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(WidgetTheme.ordinalRank(player?.ranking))
                        .font(WidgetTheme.displayFont(size: 16, weight: .heavy))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(shortName)
                        .font(WidgetTheme.roundedFont(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.white)
        }
    }

    private var shortName: String {
        guard let player else { return "—" }
        let last = player.name.split(separator: " ").last.map(String.init) ?? player.name
        return last.uppercased()
    }

    private var gaugeProgress: Double {
        guard let ranking = player?.ranking, ranking > 0 else { return 0.15 }
        // Keep under a full ring so #1 never reads as a hard white border.
        return max(0.12, min(0.82, 1.0 - Double(ranking - 1) / 24.0))
    }
}

struct LockScreenCircularCountdownView: View {
    let tour: TourPreference
    var forceSlam: GrandSlam? = nil
    var showsPreviewPlate: Bool = false

    var body: some View {
        let event = resolvedEvent
        let days = event.map { TournamentCalendar.countdown(to: $0).days } ?? 0
        let code = forceSlam?.lockDisplayName
            ?? grandSlamMatching(event)?.lockDisplayName
            ?? event?.shortName
            ?? "—"

        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .circular)
            }
            Gauge(value: min(1, Double(days) / 90.0)) {
                Image(systemName: "calendar")
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(WidgetTheme.displayFont(size: 18, weight: .heavy))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(code)
                        .font(WidgetTheme.roundedFont(size: 6, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.white)
        }
    }

    private var resolvedEvent: TournamentEvent? {
        if let forceSlam {
            return TournamentCalendar.events(for: tour).first { grandSlamMatching($0) == forceSlam }
                ?? TournamentCalendar.nextGrandSlam(for: tour)
        }
        return TournamentCalendar.nextMajor(for: tour)
    }
}

struct LockScreenCircularBadgeView: View {
    let slam: GrandSlam?
    var showsPreviewPlate: Bool = false

    var body: some View {
        let title = slam?.lockDisplayName ?? "GRAND SLAM"

        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .circular)
            }
            VStack(spacing: 2) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text(title)
                    .font(WidgetTheme.displayFont(size: 8, weight: .heavy))
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
            }
            .padding(6)
        }
    }
}
struct LockScreenCircularSeasonView: View {
    let player: TennisPlayer?
    let tour: TourPreference
    var showsPreviewPlate: Bool = false

    var body: some View {
        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .circular)
            }
            Gauge(value: winRateProgress) {
                Image(systemName: "chart.line.uptrend.xyaxis")
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(winRateLabel)
                        .font(WidgetTheme.displayFont(size: 15, weight: .heavy))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("WIN%")
                        .font(WidgetTheme.roundedFont(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.white)
        }
    }

    private var winRateProgress: Double {
        guard let record = player?.displaySeasonRecord else {
            let progress = TournamentCalendar.seasonSlamProgress(for: tour)
            return Double(progress.completed) / Double(progress.total)
        }
        let total = record.wins + record.losses
        guard total > 0 else { return 0.15 }
        return min(0.92, Double(record.wins) / Double(total))
    }

    private var winRateLabel: String {
        guard let record = player?.displaySeasonRecord else { return "—" }
        let total = record.wins + record.losses
        guard total > 0 else { return "—" }
        return "\(Int((Double(record.wins) / Double(total) * 100).rounded()))%"
    }
}

struct LockScreenRectangularNextView: View {
    let tour: TourPreference
    var forceSlam: GrandSlam? = nil
    var showsPreviewPlate: Bool = false

    var body: some View {
        let event = resolvedEvent

        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .rectangular)
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    if let event {
                        Text(event.lockDisplayName)
                            .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(event.location)
                            .font(WidgetTheme.roundedFont(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                        Text(event.surface.uppercased())
                            .font(WidgetTheme.roundedFont(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    } else {
                        Text("Season done")
                            .font(WidgetTheme.roundedFont(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer(minLength: 4)

                if let event {
                    let countdown = TournamentCalendar.countdown(to: event)
                    VStack(spacing: 1) {
                        Text("\(countdown.days)")
                            .font(WidgetTheme.displayFont(size: 20, weight: .heavy))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("days")
                            .font(WidgetTheme.roundedFont(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var resolvedEvent: TournamentEvent? {
        if let forceSlam {
            return TournamentCalendar.events(for: tour).first { grandSlamMatching($0) == forceSlam }
                ?? TournamentCalendar.nextGrandSlam(for: tour)
        }
        return TournamentCalendar.nextMajor(for: tour)
    }
}

struct LockScreenRectangularLiveView: View {
    let match: WidgetLiveMatch?
    var showsPreviewPlate: Bool = false

    var body: some View {
        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .rectangular)
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(match == nil ? Color.white.opacity(0.25) : Color.red)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    if let match {
                        Text("\(shortCode(match.player1.name)) · \(shortCode(match.player2.name))")
                            .font(WidgetTheme.roundedFont(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(match.score ?? "LIVE")
                            .font(WidgetTheme.displayFont(size: 14, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text("No live match")
                            .font(WidgetTheme.roundedFont(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    private func shortCode(_ name: String) -> String {
        let last = name.split(separator: " ").last.map(String.init) ?? name
        // Accessory rectangular is tight — keep abbreviated last names here.
        return String(last.prefix(5)).uppercased()
    }
}

struct LockScreenRectangularBadgeView: View {
    let slam: GrandSlam?
    var showsPreviewPlate: Bool = false

    var body: some View {
        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .rectangular)
            }
            HStack(spacing: 10) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: 1) {
                    Text(slam?.lockDisplayName ?? "GRAND SLAM")
                        .font(WidgetTheme.displayFont(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(slam.map { "\($0.cityShort) · \($0.surface)" } ?? "Grand Slam")
                        .font(WidgetTheme.roundedFont(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }
}

struct LockScreenRectangularFavoriteView: View {
    let player: TennisPlayer?
    var showsPreviewPlate: Bool = false

    var body: some View {
        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .rectangular)
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortName)
                        .font(WidgetTheme.displayFont(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 8, weight: .semibold))
                        Text(WidgetTheme.ordinalRank(player?.ranking))
                            .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        if let record = player?.displaySeasonRecord {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 8, weight: .semibold))
                            Text("\(record.wins)-\(record.losses)")
                                .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 4)

                Text(rankNumber)
                    .font(WidgetTheme.displayFont(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    private var shortName: String {
        guard let player else { return "PLAYER" }
        let last = player.name.split(separator: " ").last.map(String.init) ?? player.name
        return last.uppercased()
    }

    private var rankNumber: String {
        guard let ranking = player?.ranking, ranking > 0 else { return "—" }
        return String(format: "%02d", min(ranking, 99))
    }
}

struct LockScreenRectangularSeasonView: View {
    let player: TennisPlayer?
    let tour: TourPreference
    var showsPreviewPlate: Bool = false

    var body: some View {
        let progress = TournamentCalendar.seasonSlamProgress(for: tour)
        let record = player?.displaySeasonRecord

        ZStack {
            if showsPreviewPlate {
                LockScreenPreviewPlate(style: .rectangular)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(winRateLabel(record))
                        .font(WidgetTheme.displayFont(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(progress.completed)/\(progress.total) GS")
                        .font(WidgetTheme.roundedFont(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                seasonTicks(completed: progress.completed, total: progress.total)

                HStack(spacing: 10) {
                    if let record {
                        Label {
                            Text("\(record.wins)W \(record.losses)L")
                                .font(WidgetTheme.roundedFont(size: 9, weight: .bold))
                        } icon: {
                            Image(systemName: "tennisball.fill")
                                .font(.system(size: 8, weight: .semibold))
                        }
                    }
                    Label {
                        Text("\(progress.completed) majors")
                            .font(WidgetTheme.roundedFont(size: 9, weight: .bold))
                    } icon: {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white.opacity(0.55))
                .labelStyle(.titleAndIcon)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    private func winRateLabel(_ record: (wins: Int, losses: Int)?) -> String {
        guard let record else { return "—" }
        let total = record.wins + record.losses
        guard total > 0 else { return "—" }
        return "\(Int((Double(record.wins) / Double(total) * 100).rounded()))%"
    }

    private func seasonTicks(completed: Int, total: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index < completed ? 0.95 : 0.2))
                    .frame(height: 4)
            }
        }
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
    VStack(spacing: 3) {
        Text(value)
            .font(WidgetTheme.displayFont(size: 28, weight: .heavy))
            .courtifyScoreboardNumber()
            .foregroundStyle(WidgetTheme.opticYellow)
        Text(unit)
            .courtifyMicroLabel()
    }
}
