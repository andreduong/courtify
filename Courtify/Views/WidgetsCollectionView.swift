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
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case free = "Free"

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

    @State private var selectedFilter: WidgetGalleryFilter = WidgetsCollectionView.initialFilter
    @State private var showPaywall = false
    @State private var showPlayerPicker = false
    @State private var showSettings = false

    /// DEBUG-only: launch with `-UITestWidgetFilter free|small|medium|large` to
    /// preselect a gallery filter (used by agents to screenshot filter states).
    private static var initialFilter: WidgetGalleryFilter {
        #if DEBUG
        if let raw = UITestLaunchArgs.widgetFilter,
           let filter = WidgetGalleryFilter(rawValue: raw.capitalized) {
            return filter
        }
        #endif
        return .all
    }

    private var favoritePlayer: TennisPlayer? {
        FavoritePlayerCatalog.resolvedPlayer(id: favoritePlayerID, payload: dataStore.payload)
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

    /// DEBUG-only: launch with `-UITestWidgetOnly <itemID>` to render a single
    /// widget (used by agents to screenshot widgets that are below the fold).
    private static var debugOnlyItemID: String? {
        #if DEBUG
        return UITestLaunchArgs.widgetOnlyItemID
        #else
        return nil
        #endif
    }

    private var visibleSections: [WidgetGallerySection] {
        sections.compactMap { section in
            let items = section.items.filter { item in
                if let onlyID = Self.debugOnlyItemID, item.id != onlyID { return false }
                switch selectedFilter {
                case .all: return true
                case .free: return item.isFree
                case .small: return item.size == .small
                case .medium: return item.size == .medium
                case .large: return item.size == .large
                }
            }
            guard !items.isEmpty else { return nil }
            return WidgetGallerySection(id: section.id, title: section.title, items: items)
        }
    }

    var body: some View {
        CourtifyPlainScrollScreen {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Widgets collection")
                            .font(ThemeManager.roundedFont(.title2, weight: .bold))
                            .foregroundStyle(.white)

                        LastUpdatedLabel(date: dataStore.lastUpdated)
                    }

                    Spacer()

                    ProfileIconButton(showSettings: $showSettings)
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
        .onAppear {
            dataStore.loadCachedPayload()
            #if DEBUG
            if UITestLaunchArgs.opensFavoritePicker {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    showPlayerPicker = true
                }
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.favoritePlayerDidChange)) { _ in
            dataStore.loadCachedPayload()
        }
        .settingsSheet(isPresented: $showSettings)
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
        Text("Free includes your favorite player widget — no live data needed. Unlock Premium for live scores, rankings and tournament widgets.")
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
                        Spacer(minLength: 0)
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
        let isSquareSmall = item.size == .small
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
                        .frame(width: isSquareSmall ? item.size.previewHeight : nil)
                        .frame(maxWidth: isSquareSmall ? nil : .infinity)
                        .frame(height: item.size.previewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if locked {
                        Text("Premium 🎾")
                            .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(10)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !locked, item.id == "favorite" {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                            .padding(8)
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
        case "favorite":
            FavoritePlayerWidgetView(player: favoritePlayer)
                .id(favoritePlayerID)
        case "next-small": NextTournamentSmallView(tour: preferredTour)
        case "countdown": TournamentCountdownView(tour: preferredTour)
        case "next-large": NextTournamentLargeView(tour: preferredTour)
        case "calendar": SeasonCalendarView(tour: preferredTour)
        case "atp-medium": RankingsWidgetView(tour: .atp, entries: dataStore.rankings(for: .atp), limit: 5, showsRefreshHint: true)
        case "atp-large": RankingsLargeWidgetView(tour: .atp, entries: dataStore.rankings(for: .atp), showsRefreshHint: true)
        case "wta-medium": RankingsWidgetView(tour: .wta, entries: dataStore.rankings(for: .wta), limit: 5, showsRefreshHint: true)
        case "wta-large": RankingsLargeWidgetView(tour: .wta, entries: dataStore.rankings(for: .wta), showsRefreshHint: true)
        case "live": LiveScoresWidgetView(match: dataStore.payload?.liveMatches.first, showsRefreshHint: true)
        case "order": OrderOfPlayListView(matches: dataStore.payload?.upcomingMatches ?? [], showsRefreshHint: true)
        default: EmptyView()
        }
    }
}

#Preview {
    WidgetsCollectionView()
}
