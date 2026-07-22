import SwiftUI

// MARK: - Filter

private enum WidgetGalleryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case lockscreen = "Lockscreen"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case free = "Free"

    var id: String { rawValue }

    static func fromLaunchArg(_ raw: String) -> WidgetGalleryFilter? {
        switch raw.lowercased() {
        case "all": return .all
        case "lockscreen", "lock": return .lockscreen
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "free": return .free
        default: return nil
        }
    }
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

    /// DEBUG-only: launch with `-UITestWidgetFilter free|small|medium|large|lockscreen`
    private static var initialFilter: WidgetGalleryFilter {
        #if DEBUG
        if let raw = UITestLaunchArgs.widgetFilter,
           let filter = WidgetGalleryFilter.fromLaunchArg(raw) {
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

    private var sections: [CourtifyWidgetCatalog.Section] { CourtifyWidgetCatalog.sections }

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
                case .lockscreen: return item.placement == .lockScreen
                case .free: return item.isFree
                case .small: return item.size == .small
                case .medium: return item.size == .medium
                case .large: return item.size == .large
                }
            }
            guard !items.isEmpty else { return nil }
            return CourtifyWidgetCatalog.Section(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                accessLabel: section.accessLabel,
                items: items
            )
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
                // Glow as background, not a ZStack sibling: its 140pt frame was
                // driving the header's layout height and opening a dead gap
                // between "Last updated" and the filter bar.
                .background(alignment: .topLeading) {
                    CourtifyAmbientGlow(
                        primary: AppAppearanceStore.shared.liftColor,
                        secondary: AppAppearanceStore.shared.accentColor,
                        intensity: 0.55,
                        anchor: .top
                    )
                    .frame(height: 140)
                    .offset(y: -40)
                    .allowsHitTesting(false)
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
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.appAppearanceDidChange)) { _ in
            colorRefreshTick += 1
        }
    }

    private var freeExplainer: some View {
        Text("Free includes Favorite player widgets (home + Lock Screen). Unlock Premium for badges, season progress, live scores, rankings, and tournament widgets.")
            .font(ThemeManager.roundedFont(.footnote))
            .foregroundStyle(.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Filter bar

    private var filterBar: some View {
        HStack(spacing: 3) {
            ForEach(WidgetGalleryFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                Button {
                    CourtifyMotion.animateSelection { selectedFilter = filter }
                } label: {
                    Text(filter.rawValue)
                        .font(ThemeManager.roundedFont(size: 11, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? ThemeManager.opticYellow : .white.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Capsule()
                                    .fill(ThemeManager.opticYellow)
                                    .frame(height: 2)
                                    .padding(.horizontal, 2)
                            }
                        }
                }
                .courtifyButton(.ghost)
            }
        }
        .courtifySelectionFeedback(selectedFilter)
    }

    // MARK: Sections

    private func sectionView(_ section: CourtifyWidgetCatalog.Section) -> some View {
        let isLockSection = section.items.contains { $0.placement == .lockScreen }

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(section.title)
                        .font(ThemeManager.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(.white)
                    if let access = section.accessLabel {
                        Text(access.rawValue.uppercased())
                            .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                            .foregroundStyle(
                                access == .free ? ThemeManager.opticYellow : .white.opacity(0.55)
                            )
                    }
                }
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(ThemeManager.roundedFont(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isLockSection {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(section.items) { item in
                        lockWidgetCard(for: item)
                    }
                    Spacer(minLength: 0)
                }
            } else {
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

            if section.id == "favorite", showsFavoriteMediaHint {
                Text("Photo unavailable right now (API limit). Rank still updates from cache.")
                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showsFavoriteMediaHint: Bool {
        guard let player = favoritePlayer, player.isCustom else { return false }
        guard FavoritePlayerEnricher.mediaFailureReason == .quota else { return false }
        return !PlayerPhotoStore.hasCachedPhotos(playerID: player.id)
    }

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

    /// Lock Screen cards — accessory-sized widgets only (no purple container).
    @ViewBuilder
    private func lockWidgetCard(for item: CourtifyWidgetCatalog.Item) -> some View {
        let locked = isLocked(item)

        VStack(alignment: .leading, spacing: 8) {
            Button {
                if locked {
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
            }
            .courtifyButton(.card)

            Text(item.title)
                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
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

                if canRecolor {
                    Button {
                        if isEntitled {
                            colorPickerItem = item
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        if isEntitled {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background {
                                    Circle()
                                        .fill(.thinMaterial)
                                }
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                                }
                        } else {
                            CourtifyGlassLockBadge()
                        }
                    }
                    .courtifyButton(.icon)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                } else if locked {
                    CourtifyGlassLockBadge()
                        .padding(10)
                        .allowsHitTesting(false)
                }

                if !locked, item.id == "favorite" || item.id == "favorite-medium" {
                    Button {
                        showPlayerPicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background {
                                Circle()
                                    .fill(.thinMaterial)
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                            }
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
            }
            .lineLimit(1)
        }
        .frame(maxWidth: isSquareSmall ? previewHeight : .infinity, alignment: .leading)
    }
}

#Preview {
    WidgetsCollectionView()
}
