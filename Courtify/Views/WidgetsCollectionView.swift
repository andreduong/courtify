import SwiftUI

// MARK: - Filter

private enum WidgetGalleryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case free = "Free"

    var id: String { rawValue }
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
    @State private var colorPickerItem: CourtifyWidgetCatalog.Item?
    @State private var shareItem: CourtifyWidgetCatalog.Item?
    @State private var colorRefreshTick = 0

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

    /// Gallery sections come from `CourtifyWidgetCatalog` — same source as WidgetKit kinds.
    private var sections: [CourtifyWidgetCatalog.Section] { CourtifyWidgetCatalog.sections }

    /// DEBUG-only: launch with `-UITestWidgetOnly <itemID>` to render a single
    /// widget (used by agents to screenshot widgets that are below the fold).
    private static var debugOnlyItemID: String? {
        #if DEBUG
        return UITestLaunchArgs.widgetOnlyItemID
        #else
        return nil
        #endif
    }

    private var visibleSections: [CourtifyWidgetCatalog.Section] {
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
            return CourtifyWidgetCatalog.Section(id: section.id, title: section.title, items: items)
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
            if let colorID = UITestLaunchArgs.widgetColorItemID {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if isEntitled, let item = galleryItem(id: colorID) {
                        colorPickerItem = item
                    } else if !isEntitled {
                        showPaywall = true
                    }
                }
            }
            if let shareID = UITestLaunchArgs.widgetShareItemID {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let item = galleryItem(id: shareID), !isLocked(item) {
                        CourtifyMotion.animateModal { shareItem = item }
                    } else if let item = galleryItem(id: shareID), isLocked(item) {
                        showPaywall = true
                    }
                }
            }
            #endif
        }
        .task(id: favoritePlayerID) {
            await FavoritePlayerEnricher.ensureLoaded(
                playerID: favoritePlayerID,
                payload: dataStore.payload
            )
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
        .sheet(item: $colorPickerItem) { item in
            WidgetColorPickerSheet(
                widgetID: item.id,
                title: item.title,
                onRequestPaywall: { showPaywall = true }
            )
        }
        .fullScreenCover(item: $shareItem) { item in
            WidgetShareView(
                item: item,
                favoritePlayer: favoritePlayer,
                favoritePlayerID: favoritePlayerID,
                tour: preferredTour,
                payload: dataStore.payload,
                onClose: {
                    CourtifyMotion.animateModal { shareItem = nil }
                }
            )
            .courtifyInteractiveChrome()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.widgetColorDidChange)) { _ in
            colorRefreshTick += 1
        }
    }

    private var freeExplainer: some View {
        Text("Free includes your favorite player widgets (home + Lock Screen rank) — no live data needed. Unlock Premium for live scores, rankings, tournament and Lock Screen countdown widgets.")
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

    private func sectionView(_ section: CourtifyWidgetCatalog.Section) -> some View {
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

            if section.id == "favorite", showsFavoriteMediaHint {
                Text("Photo & season record unavailable right now (daily API limit). Rank still updates from cache.")
                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showsFavoriteMediaHint: Bool {
        guard let player = favoritePlayer, player.isCustom else { return false }
        if FavoritePlayerEnricher.mediaUnavailable { return true }
        return player.displaySeasonRecord == nil
            && !PlayerPhotoStore.hasCachedPhotos(playerID: player.id)
    }

    /// Small widgets pair up two per row; medium/large span the full width.
    private func chunkedRows(_ items: [CourtifyWidgetCatalog.Item]) -> [[CourtifyWidgetCatalog.Item]] {
        var rows: [[CourtifyWidgetCatalog.Item]] = []
        var pendingSmall: CourtifyWidgetCatalog.Item?
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

    private func isLocked(_ item: CourtifyWidgetCatalog.Item) -> Bool {
        !item.isFree && !isEntitled
    }

    private func galleryItem(id: String) -> CourtifyWidgetCatalog.Item? {
        CourtifyWidgetCatalog.item(id: id)
    }

    @ViewBuilder
    private func widgetCard(for item: CourtifyWidgetCatalog.Item) -> some View {
        let locked = isLocked(item)
        let isSquareSmall = item.size == .small
        let canRecolor = WidgetColorStyle.isCustomizable(item.id)
        let previewWidth: CGFloat? = isSquareSmall ? item.size.previewHeight : nil
        let previewHeight = item.size.previewHeight

        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button {
                    // Free users on Premium widgets → paywall only (never share).
                    if isLocked(item) {
                        showPaywall = true
                    } else {
                        CourtifyMotion.animateModal { shareItem = item }
                    }
                } label: {
                    WidgetGalleryPreview(
                        item: item,
                        favoritePlayer: favoritePlayer,
                        favoritePlayerID: favoritePlayerID,
                        tour: preferredTour,
                        payload: dataStore.payload
                    )
                    .id("\(item.id)-\(colorRefreshTick)")
                    .frame(width: previewWidth)
                    .frame(maxWidth: isSquareSmall ? nil : .infinity)
                    .frame(height: previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .courtifyButton(.card)

                if locked {
                    Text("Premium 🎾")
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(10)
                        .allowsHitTesting(false)
                }

                if canRecolor {
                    Button {
                        if isEntitled {
                            colorPickerItem = item
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: isEntitled ? "circle.lefthalf.filled" : "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .courtifyButton(.icon)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                if !locked, item.id == "favorite" || item.id == "favorite-medium" {
                    Button {
                        showPlayerPicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .courtifyButton(.icon)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: previewWidth)
            .frame(maxWidth: isSquareSmall ? nil : .infinity)
            .frame(height: previewHeight)

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
        .frame(maxWidth: isSquareSmall ? previewHeight : .infinity, alignment: .leading)
    }
}

#Preview {
    WidgetsCollectionView()
}
