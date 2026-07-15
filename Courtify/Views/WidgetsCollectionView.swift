import SwiftUI

// MARK: - Catalog model

private enum WidgetGallerySize: String {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var previewHeight: CGFloat {
        switch self {
        case .small: 165
        case .medium: 165
        case .large: 330
        }
    }
}

private enum WidgetGalleryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case free = "Free"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }
}

private struct WidgetGalleryItem: Identifiable {
    let id: String
    let title: String
    let size: WidgetGallerySize
    var isFree: Bool = false
}

private struct WidgetGallerySection: Identifiable {
    let id: String
    let title: String
    let items: [WidgetGalleryItem]
}

// MARK: - View

struct WidgetsCollectionView: View {
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.userDefaults)
    private var favoritePlayerID = ""

    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.userDefaults)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared

    @State private var selectedFilter: WidgetGalleryFilter = .all
    @State private var showPaywall = false
    @State private var showPlayerPicker = false

    private var favoritePlayer: TennisPlayer? {
        TennisPlayer.player(for: favoritePlayerID)
    }

    private var preferredTour: TourPreference {
        let tour = TourPreference(rawValue: tourPreferenceRaw) ?? .atp
        return tour == .both ? .atp : tour
    }

    private var isEntitled: Bool {
        revenueCat.isProUser || AppGroupConstants.referralBypassActive
    }

    private let sections: [WidgetGallerySection] = [
        WidgetGallerySection(id: "favorite", title: "Favorite player", items: [
            WidgetGalleryItem(id: "favorite", title: "Favorite player", size: .small, isFree: true),
        ]),
        WidgetGallerySection(id: "tournaments", title: "Tournament widgets", items: [
            WidgetGalleryItem(id: "next-small", title: "Next tournament", size: .small),
            WidgetGalleryItem(id: "countdown", title: "Tournament countdown", size: .medium),
            WidgetGalleryItem(id: "next-large", title: "Next tournament", size: .large),
            WidgetGalleryItem(id: "calendar", title: "Season calendar", size: .large),
        ]),
        WidgetGallerySection(id: "atp", title: "ATP widgets", items: [
            WidgetGalleryItem(id: "atp-medium", title: "ATP standings", size: .medium),
            WidgetGalleryItem(id: "atp-large", title: "ATP standings", size: .large),
        ]),
        WidgetGallerySection(id: "wta", title: "WTA widgets", items: [
            WidgetGalleryItem(id: "wta-medium", title: "WTA standings", size: .medium),
            WidgetGalleryItem(id: "wta-large", title: "WTA standings", size: .large),
        ]),
        WidgetGallerySection(id: "live", title: "Live widgets", items: [
            WidgetGalleryItem(id: "live", title: "Live scores", size: .small),
            WidgetGalleryItem(id: "order", title: "Order of play", size: .large),
        ]),
    ]

    private var visibleSections: [WidgetGallerySection] {
        sections.compactMap { section in
            let items = section.items.filter { item in
                switch selectedFilter {
                case .all: true
                case .free: item.isFree
                case .small: item.size == .small
                case .medium: item.size == .medium
                case .large: item.size == .large
                }
            }
            guard !items.isEmpty else { return nil }
            return WidgetGallerySection(id: section.id, title: section.title, items: items)
        }
    }

    var body: some View {
        CourtifyPlainScrollScreen {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Widgets collection")
                        .font(ThemeManager.roundedFont(.title2, weight: .bold))
                        .foregroundStyle(.white)

                    LastUpdatedLabel(date: dataStore.lastUpdated)
                }

                filterBar

                if selectedFilter == .free {
                    freeExplainer
                }

                ForEach(visibleSections) { section in
                    sectionView(section)
                }
            }
            .padding(.horizontal, 20)
            .animation(CourtifyMotion.selection, value: selectedFilter)
        }
        .refreshable {
            await dataStore.refresh()
        }
        .onAppear { dataStore.loadCachedPayload() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                favoritePlayerID: favoritePlayerID.isEmpty ? "sinner" : favoritePlayerID,
                managesOwnCloseButton: true,
                onSubscribed: { showPaywall = false },
                onClose: { showPaywall = false },
                onSkip: { showPaywall = false }
            )
        }
        .sheet(isPresented: $showPlayerPicker) {
            FavoritePlayerPickerSheet(favoritePlayerID: $favoritePlayerID)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var freeExplainer: some View {
        Text("Free includes your favorite player widget — no live data needed. Unlock Pro for live scores, rankings and tournament widgets.")
            .font(ThemeManager.roundedFont(.footnote))
            .foregroundStyle(.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WidgetGalleryFilter.allCases) { filter in
                    Button {
                        CourtifyMotion.animateSelection { selectedFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                            .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.white.opacity(0.18) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .courtifyButton(.ghost)
                }
            }
        }
        .padding(.horizontal, -20)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    // MARK: Sections

    private func sectionView(_ section: WidgetGallerySection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title)
                .font(ThemeManager.roundedFont(.headline, weight: .bold))
                .foregroundStyle(.white)

            ForEach(chunkedRows(section.items), id: \.first!.id) { row in
                if row.count == 2 {
                    HStack(alignment: .top, spacing: 16) {
                        widgetCard(for: row[0])
                        widgetCard(for: row[1])
                    }
                } else if row[0].size == .small {
                    HStack(alignment: .top, spacing: 16) {
                        widgetCard(for: row[0])
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                } else {
                    widgetCard(for: row[0])
                }
            }
        }
    }

    /// Small widgets pair up two per row; medium/large span the full width.
    private func chunkedRows(_ items: [WidgetGalleryItem]) -> [[WidgetGalleryItem]] {
        var rows: [[WidgetGalleryItem]] = []
        var pendingSmall: WidgetGalleryItem?
        for item in items {
            if item.size == .small {
                if let first = pendingSmall {
                    rows.append([first, item])
                    pendingSmall = nil
                } else {
                    pendingSmall = item
                }
            } else {
                if let first = pendingSmall {
                    rows.append([first])
                    pendingSmall = nil
                }
                rows.append([item])
            }
        }
        if let first = pendingSmall {
            rows.append([first])
        }
        return rows
    }

    // MARK: Card chrome

    private func isLocked(_ item: WidgetGalleryItem) -> Bool {
        !item.isFree && !isEntitled
    }

    @ViewBuilder
    private func widgetCard(for item: WidgetGalleryItem) -> some View {
        let locked = isLocked(item)
        VStack(spacing: 8) {
            Button {
                if locked {
                    showPaywall = true
                } else if item.id == "favorite" {
                    showPlayerPicker = true
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    previewContent(for: item)
                        .frame(maxWidth: .infinity)
                        .frame(height: item.size.previewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if locked {
                        Text("PRO 🎾")
                            .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(10)
                    } else if item.id == "favorite" {
                        Text("Customize 🖌️")
                            .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(10)
                    }
                }
            }
            .courtifyButton(.card)
            .disabled(!locked && item.id != "favorite")

            HStack(spacing: 6) {
                Text(item.title)
                    .font(ThemeManager.roundedFont(.footnote, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(item.size.rawValue)
                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                if item.isFree {
                    Text("FREE")
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)
                }
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private func previewContent(for item: WidgetGalleryItem) -> some View {
        switch item.id {
        case "favorite": FavoritePlayerWidgetPreview(player: favoritePlayer)
        case "next-small": NextTournamentSmallPreview(tour: preferredTour)
        case "countdown": TournamentCountdownPreview(tour: preferredTour)
        case "next-large": NextTournamentLargePreview(tour: preferredTour)
        case "calendar": SeasonCalendarPreview(tour: preferredTour)
        case "atp-medium": RankingsWidgetPreview(tour: .atp, entries: dataStore.rankings(for: .atp), limit: 5)
        case "atp-large": RankingsLargeWidgetPreview(tour: .atp, entries: dataStore.rankings(for: .atp))
        case "wta-medium": RankingsWidgetPreview(tour: .wta, entries: dataStore.rankings(for: .wta), limit: 5)
        case "wta-large": RankingsLargeWidgetPreview(tour: .wta, entries: dataStore.rankings(for: .wta))
        case "live": LiveScoresWidgetPreview(match: dataStore.payload?.liveMatches.first)
        case "order": OrderOfPlayWidgetPreview(matches: dataStore.payload?.upcomingMatches ?? [])
        default: EmptyView()
        }
    }
}

// MARK: - Favorite player (free, bundled data only)

private struct FavoritePlayerWidgetPreview: View {
    let player: TennisPlayer?

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
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [ThemeManager.emeraldGreen, ThemeManager.midnightGreen],
                startPoint: .top,
                endPoint: .bottom
            )

            if let player {
                CachedBundledImage(name: player.heroImageName, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.leading, 60)
                    .opacity(0.95)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player?.tour.rawValue ?? "ATP")
                    .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                    .foregroundStyle(ThemeManager.opticYellow)

                Text(player?.name ?? "Pick a player")
                    .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .frame(maxWidth: 90, alignment: .leading)

                Spacer()

                Text(rankLabel)
                    .font(ThemeManager.roundedFont(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                if let record = player?.seasonRecord {
                    Text("\(record.wins)-\(record.losses) season")
                        .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Tournament widgets (bundled calendar, zero API cost)

private struct NextTournamentSmallPreview: View {
    let tour: TourPreference

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack(alignment: .topLeading) {
            surfaceGradient(for: event)
            VStack(alignment: .leading, spacing: 4) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)

                    Text(event.dateRangeLabel)
                        .font(ThemeManager.roundedFont(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)

                    Text(event.tier.rawValue)
                        .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    let countdown = TournamentCalendar.countdown(to: event)
                    Text("\(countdown.days) days, \(countdown.hours) hr")
                        .font(ThemeManager.roundedFont(.footnote, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)
                } else {
                    Text("Season complete")
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(14)
        }
    }
}

private struct TournamentCountdownPreview: View {
    let tour: TourPreference

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack {
            if let imageName = event?.heroImageName {
                CachedBundledImage(name: imageName, contentMode: .fill)
                    .overlay(Color.black.opacity(0.45))
            } else {
                surfaceGradient(for: event)
            }

            VStack(spacing: 4) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(event.dateRangeLabel)
                        .font(ThemeManager.roundedFont(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    let countdown = TournamentCalendar.countdown(to: event)
                    Text("\(countdown.days) DAYS, \(countdown.hours) HR")
                        .font(ThemeManager.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)

                    Text("\(event.name) 2026")
                        .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("Season complete")
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
        }
    }
}

private struct NextTournamentLargePreview: View {
    let tour: TourPreference

    private var upcoming: [TournamentEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return TournamentCalendar.events(for: tour)
            .filter { $0.endDate >= today }
    }

    var body: some View {
        let event = TournamentCalendar.nextMajor(for: tour)
        ZStack(alignment: .topLeading) {
            surfaceGradient(for: event)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let event {
                        Text("\(event.shortName) · \(event.location.uppercased())")
                            .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)

                        Text(event.dateRangeLabel)
                            .font(ThemeManager.roundedFont(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        Text("2026 · \(event.surface)")
                            .font(ThemeManager.roundedFont(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        let countdown = TournamentCalendar.countdown(to: event)
                        HStack(spacing: 12) {
                            countdownCell(String(format: "%02d", countdown.days), unit: "DAYS")
                            countdownCell(String(format: "%02d", countdown.hours), unit: "HOURS")
                            countdownCell(String(format: "%02d", countdown.minutes), unit: "MIN")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Text("COMING UP")
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))

                    ForEach(upcoming.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Text(item.listDateLabel)
                                .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                                .foregroundStyle(ThemeManager.opticYellow)
                                .frame(width: 44, alignment: .leading)
                            Text(item.name)
                                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: 150, alignment: .leading)
            }
            .padding(16)
        }
    }

    private func countdownCell(_ value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ThemeManager.roundedFont(size: 24, weight: .bold))
                .foregroundStyle(ThemeManager.opticYellow)
            Text(unit)
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct SeasonCalendarPreview: View {
    let tour: TourPreference

    private var events: [TournamentEvent] {
        TournamentCalendar.events(for: tour)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x11221A), ThemeManager.midnightGreen],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Text("2026 \(tour.rawValue) CALENDAR")
                    .font(ThemeManager.roundedFont(.footnote, weight: .bold))
                    .foregroundStyle(.white)

                let midpoint = (events.count + 1) / 2
                HStack(alignment: .top, spacing: 14) {
                    calendarColumn(Array(events.prefix(midpoint)))
                    calendarColumn(Array(events.dropFirst(midpoint)))
                }
            }
            .padding(14)
        }
    }

    private func calendarColumn(_ column: [TournamentEvent]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(column) { event in
                HStack(spacing: 6) {
                    Text(event.listDateLabel)
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 42, alignment: .leading)

                    if !event.isUpcoming {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(ThemeManager.courtGreen)
                    }

                    Text(event.name)
                        .font(ThemeManager.roundedFont(.caption2, weight: event.tier == .grandSlam ? .bold : .medium))
                        .foregroundStyle(event.tier == .grandSlam ? .white : .white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Slam-colored gradient (bundled accent colors, no assets fetched).
private func surfaceGradient(for event: TournamentEvent?) -> LinearGradient {
    let accent: UInt
    switch event?.surface {
    case "Clay": accent = 0xE35205
    case "Grass": accent = 0x006633
    case "Hard": accent = 0x0085CA
    default: accent = 0x00703C
    }
    return LinearGradient(
        colors: [Color(hex: accent), ThemeManager.midnightGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Rankings widgets (live data via pull-to-refresh)

private struct RankingsWidgetPreview: View {
    let tour: TourPreference
    let entries: [WidgetRankingEntry]
    let limit: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tour == .atp ? Color(hex: 0x0C2340) : Color(hex: 0x3D1E52), ThemeManager.midnightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("\(tour.rawValue) TOP \(limit)")
                    .font(ThemeManager.roundedFont(.caption, weight: .bold))
                    .foregroundStyle(.white)

                if entries.isEmpty {
                    Spacer()
                    RefreshHintLabel()
                    Spacer()
                } else {
                    ForEach(entries.prefix(limit)) { entry in
                        RankingRow(entry: entry)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RankingsLargeWidgetPreview: View {
    let tour: TourPreference
    let entries: [WidgetRankingEntry]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tour == .atp ? Color(hex: 0x0C2340) : Color(hex: 0x3D1E52), ThemeManager.midnightGreen],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Text("2026 \(tour.rawValue) RANKINGS")
                    .font(ThemeManager.roundedFont(.footnote, weight: .bold))
                    .foregroundStyle(.white)

                if entries.isEmpty {
                    Spacer()
                    RefreshHintLabel()
                    Spacer()
                } else {
                    let top10 = Array(entries.prefix(10))
                    let midpoint = min(5, top10.count)
                    HStack(alignment: .top, spacing: 16) {
                        rankingColumn(Array(top10.prefix(midpoint)))
                        rankingColumn(Array(top10.dropFirst(midpoint)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
    }

    private func rankingColumn(_ column: [WidgetRankingEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(column) { entry in
                RankingRow(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RankingRow: View {
    let entry: WidgetRankingEntry

    var body: some View {
        HStack(spacing: 8) {
            Text("\(entry.rank ?? 0)")
                .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.player.name)
                    .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let country = entry.player.country {
                    Text(country)
                        .font(ThemeManager.roundedFont(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 4)

            if let points = entry.points {
                Text("\(points)")
                    .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                    .foregroundStyle(ThemeManager.opticYellow)
            }
        }
    }
}

// MARK: - Live widgets (live data via pull-to-refresh)

private struct LiveScoresWidgetPreview: View {
    let match: WidgetLiveMatch?

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: 0x143D2B), ThemeManager.midnightGreen],
                startPoint: .top,
                endPoint: .bottom
            )

            if let match {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ThemeManager.opticYellow)
                            .frame(width: 6, height: 6)
                        Text("LIVE · \(match.tour)")
                            .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                            .foregroundStyle(ThemeManager.opticYellow)
                    }

                    if let tournament = match.tournament {
                        Text(tournament)
                            .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(match.player1.name)
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(match.player2.name)
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let score = match.score {
                        Text(score)
                            .font(ThemeManager.roundedFont(.footnote, weight: .bold))
                            .foregroundStyle(ThemeManager.opticYellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(14)
            } else {
                VStack(spacing: 6) {
                    Text("No live matches")
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    RefreshHintLabel()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct OrderOfPlayWidgetPreview: View {
    let matches: [WidgetUpcomingMatch]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: 0x0C2340), ThemeManager.midnightGreen],
                startPoint: .leading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("ORDER OF PLAY")
                    .font(ThemeManager.roundedFont(.footnote, weight: .bold))
                    .foregroundStyle(.white)

                if matches.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("No upcoming matches")
                                .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            RefreshHintLabel()
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(matches.prefix(6), id: \.displayID) { match in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(match.court ?? match.tournament ?? match.tour)
                                    .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                                    .foregroundStyle(ThemeManager.opticYellow)
                                    .lineLimit(1)
                                if let startTime = match.startTime {
                                    Text(Self.timeFormatter.string(from: startTime))
                                        .font(ThemeManager.roundedFont(size: 9, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .frame(width: 84, alignment: .leading)

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
                        .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
    }
}

private struct RefreshHintLabel: View {
    var body: some View {
        Text("Pull down to refresh")
            .font(ThemeManager.roundedFont(.caption2))
            .foregroundStyle(.white.opacity(0.55))
    }
}

// MARK: - Favorite player picker (free customization, bundled data)

private struct FavoritePlayerPickerSheet: View {
    @Binding var favoritePlayerID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(TennisPlayer.topPlayers) { player in
                        Button {
                            favoritePlayerID = player.id
                            AppGroupConstants.updateFavoritePlayer(player.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                CachedBundledImage(name: player.resolvedImageName, contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(ThemeManager.roundedFont(.body, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(player.tour.rawValue) · No. \(player.ranking)")
                                        .font(ThemeManager.roundedFont(.caption, weight: .medium))
                                        .foregroundStyle(ThemeManager.courtGreen)
                                }

                                Spacer()

                                if favoritePlayerID == player.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ThemeManager.opticYellow)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .courtifyButton(.card)

                        CourtifyTileDivider()
                    }
                }
                .padding(.top, 8)
            }
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
            .navigationTitle("Favorite player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ThemeManager.opticYellow)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WidgetsCollectionView()
}
