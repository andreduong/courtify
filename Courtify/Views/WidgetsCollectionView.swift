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

    @State private var selectedFilter: WidgetGalleryFilter = WidgetsCollectionView.initialFilter
    @State private var showPaywall = false
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
        // Local catalog only — gallery is a preview surface (no Worker fetch).
        FavoritePlayerCatalog.resolvedPlayer(id: favoritePlayerID, payload: nil)
            ?? WidgetPreviewSamples.favoritePlayer
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
                case .small: return item.placement == .homeScreen && item.size == .small
                case .medium: return item.placement == .homeScreen && item.size == .medium
                case .large: return item.placement == .homeScreen && item.size == .large
                }
            }
            guard !items.isEmpty else { return nil }
            return CourtifyWidgetCatalog.Section(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                accessLabel: isEntitled ? nil : section.accessLabel,
                items: items
            )
        }
    }

    var body: some View {
        CourtifyPlainScrollScreen {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    Text("Widgets collection")
                        .font(ThemeManager.roundedFont(.title2, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    ProfileIconButton(showSettings: $showSettings)
                }
                // Glow as background, not a ZStack sibling: its 140pt frame was
                // driving the header's layout height and opening a dead gap
                // between the title and the filter bar.
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

                if selectedFilter == .all {
                    allSizeOrderedGallery
                } else if flattensBySize {
                    flatSizeGallery
                } else if selectedFilter == .lockscreen {
                    denseLockScreenGallery
                } else {
                    ForEach(visibleSections) { section in
                        sectionView(section)
                    }
                }
            }
            .padding(.horizontal, 20)
            .animation(CourtifyMotion.selection, value: selectedFilter)
        }
        // Preview-only gallery — no pull-to-refresh (avoids Worker / RapidAPI burn).
        .onAppear {
            #if DEBUG
            if UITestLaunchArgs.opensFavoritePicker {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let item = galleryItem(id: "favorite") {
                        colorPickerItem = item
                    }
                }
            }
            if let colorID = UITestLaunchArgs.widgetColorItemID {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let item = galleryItem(id: colorID) {
                        colorPickerItem = item
                    }
                }
            }
            if let shareID = UITestLaunchArgs.widgetShareItemID {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let item = galleryItem(id: shareID) {
                        openWidgetCustomization(for: item)
                    }
                }
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.favoritePlayerDidChange)) { _ in
            colorRefreshTick += 1
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
                payload: nil,
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

    /// Size filters (Small / Medium / Large) flatten into one continuous Formulify-style
    /// grid so orphan cards don't leave a blank half-row under sparse section headers.
    private var flattensBySize: Bool {
        switch selectedFilter {
        case .small, .medium, .large: return true
        case .all, .lockscreen, .free: return false
        }
    }

    private var flatGalleryItems: [CourtifyWidgetCatalog.Item] {
        visibleSections.flatMap(\.items)
    }

    /// All tab: home smalls 2×2 → Lock Screen (favorite badges first) → medium/large.
    private var allSizeOrderedGallery: some View {
        let homeItems = visibleSections
            .flatMap(\.items)
            .filter { $0.placement == .homeScreen }
        let smalls = orderedHomeSmalls(homeItems.filter { $0.size == .small })
        let mediums = homeItems.filter { $0.size == .medium }
        let larges = homeItems.filter { $0.size == .large }
        let favoriteLock = visibleSections
            .first { $0.id == "lock-favorite" }?
            .items ?? []
        let premiumLock = visibleSections
            .filter { $0.items.contains { $0.placement == .lockScreen } && $0.id != "lock-favorite" }
            .flatMap(\.items)

        return VStack(alignment: .leading, spacing: 22) {
            if !smalls.isEmpty {
                homeSmallGrid(smalls)
            }

            if !favoriteLock.isEmpty || !premiumLock.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    lockChapterHeader(
                        title: "Lock Screen",
                        access: isEntitled ? nil : .premium
                    )
                    if !favoriteLock.isEmpty {
                        lockItemsGrid(favoriteLock)
                    }
                    if !premiumLock.isEmpty {
                        lockItemsGrid(premiumLock)
                    }
                }
            }

            ForEach(mediums) { item in
                widgetCard(for: item)
            }
            ForEach(larges) { item in
                widgetCard(for: item)
            }
        }
    }

    /// Product order for the All 2×2: favorite → next → live → rankings.
    private func orderedHomeSmalls(_ items: [CourtifyWidgetCatalog.Item]) -> [CourtifyWidgetCatalog.Item] {
        let rank: [String: Int] = [
            "favorite": 0,
            "next-small": 1,
            "live": 2,
            "rankings-small": 3,
        ]
        return items.sorted { (rank[$0.id] ?? 50) < (rank[$1.id] ?? 50) }
    }

    @ViewBuilder
    private var flatSizeGallery: some View {
        switch selectedFilter {
        case .small:
            homeSmallGrid(orderedHomeSmalls(flatGalleryItems))
        case .medium, .large:
            VStack(alignment: .leading, spacing: 16) {
                ForEach(flatGalleryItems) { item in
                    widgetCard(for: item)
                }
            }
        default:
            EmptyView()
        }
    }

    /// Lockscreen filter: keep Free / Premium chapter labels, but pack every
    /// accessory in that chapter into a denser multi-column strip (3 circulars
    /// or 2 rectangulars across) so badges aren't stranded with a blank half-row.
    private var denseLockScreenGallery: some View {
        let favoriteLock = visibleSections
            .first { $0.id == "lock-favorite" }?
            .items ?? []
        let premiumLock = visibleSections
            .filter { $0.items.contains { $0.placement == .lockScreen } && $0.id != "lock-favorite" }
            .flatMap(\.items)

        return VStack(alignment: .leading, spacing: 14) {
            lockChapterHeader(
                title: "Lock Screen",
                access: isEntitled ? nil : .premium
            )
            if !favoriteLock.isEmpty {
                lockItemsGrid(favoriteLock)
            }
            if !premiumLock.isEmpty {
                lockItemsGrid(premiumLock)
            }
        }
    }

    private func lockChapterHeader(
        title: String,
        access: CourtifyWidgetCatalog.Section.AccessLabel?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(ThemeManager.roundedFont(.headline, weight: .bold))
                .foregroundStyle(.white)
            if let access {
                Text(access.rawValue.uppercased())
                    .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                    .foregroundStyle(
                        access == .free ? ThemeManager.opticYellow : .white.opacity(0.55)
                    )
            }
        }
    }

    private func sectionView(_ section: CourtifyWidgetCatalog.Section) -> some View {
        let isLockSection = section.items.contains { $0.placement == .lockScreen }

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(section)

            if isLockSection {
                lockItemsGrid(section.items)
            } else {
                homeItemsGrid(section.items)
            }
        }
    }

    private func sectionHeader(_ section: CourtifyWidgetCatalog.Section) -> some View {
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
    }

    // MARK: Home grid (Formulify-style)

    private static let homeSmallColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private func homeItemsGrid(_ items: [CourtifyWidgetCatalog.Item]) -> some View {
        let smalls = items.filter { $0.size == .small }
        let rest = items.filter { $0.size != .small }

        return VStack(alignment: .leading, spacing: 16) {
            if !smalls.isEmpty {
                homeSmallGrid(smalls)
            }
            ForEach(rest) { item in
                widgetCard(for: item)
            }
        }
    }

    private func homeSmallGrid(_ items: [CourtifyWidgetCatalog.Item]) -> some View {
        LazyVGrid(columns: Self.homeSmallColumns, alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                widgetCard(for: item, fillsGridCell: true)
            }
        }
    }

    // MARK: Lock Screen grid (dense accessory packing)

    /// Circular accessories are compact enough for 3-across; rectangulars pair 2-across.
    /// Mixed rows pack circular + rectangular without a trailing blank Spacer.
    private static let lockCircularColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private static let lockRectangularColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private func lockItemsGrid(_ items: [CourtifyWidgetCatalog.Item]) -> some View {
        let circulars = items.filter { $0.size == .small }
        let rectangulars = items.filter { $0.size != .small }

        return VStack(alignment: .leading, spacing: 14) {
            if !circulars.isEmpty && rectangulars.isEmpty {
                LazyVGrid(columns: Self.lockCircularColumns, alignment: .leading, spacing: 14) {
                    ForEach(circulars) { item in
                        lockWidgetCard(for: item, expands: true)
                    }
                }
            } else if circulars.isEmpty && !rectangulars.isEmpty {
                if rectangulars.count == 1 {
                    // Lone rectangular shouldn't sit in a half-row blank.
                    lockWidgetCard(for: rectangulars[0], expands: true)
                } else {
                    LazyVGrid(columns: Self.lockRectangularColumns, alignment: .leading, spacing: 14) {
                        ForEach(rectangulars) { item in
                            lockWidgetCard(for: item, expands: true)
                        }
                    }
                }
            } else {
                // Mixed: pack each circular beside a rectangular when possible,
                // then spill remaining circulars into a 3-col strip.
                ForEach(Array(lockMixedRows(circulars: circulars, rectangulars: rectangulars).enumerated()), id: \.offset) { _, row in
                    lockMixedRow(row)
                }
            }
        }
    }

    private struct LockMixedRow: Identifiable {
        let id: String
        let circulars: [CourtifyWidgetCatalog.Item]
        let rectangulars: [CourtifyWidgetCatalog.Item]
    }

    private func lockMixedRows(
        circulars: [CourtifyWidgetCatalog.Item],
        rectangulars: [CourtifyWidgetCatalog.Item]
    ) -> [LockMixedRow] {
        var remainingCirc = circulars
        var remainingRect = rectangulars
        var rows: [LockMixedRow] = []

        // Formulify-style: pack up to 2 circulars beside each rectangular, then
        // spill leftover circulars 3-across and leftover rectangulars 2-across.
        while !remainingCirc.isEmpty && !remainingRect.isEmpty {
            let rect = remainingRect.removeFirst()
            let take = min(2, remainingCirc.count)
            let paired = Array(remainingCirc.prefix(take))
            remainingCirc.removeFirst(take)
            rows.append(LockMixedRow(id: rect.id, circulars: paired, rectangulars: [rect]))
        }
        while !remainingCirc.isEmpty {
            let chunk = Array(remainingCirc.prefix(3))
            remainingCirc.removeFirst(chunk.count)
            rows.append(LockMixedRow(
                id: chunk.map(\.id).joined(separator: "+"),
                circulars: chunk,
                rectangulars: []
            ))
        }
        while !remainingRect.isEmpty {
            let chunk = Array(remainingRect.prefix(2))
            remainingRect.removeFirst(chunk.count)
            rows.append(LockMixedRow(
                id: chunk.map(\.id).joined(separator: "+"),
                circulars: [],
                rectangulars: chunk
            ))
        }
        return rows
    }

    @ViewBuilder
    private func lockMixedRow(_ row: LockMixedRow) -> some View {
        if !row.circulars.isEmpty && !row.rectangulars.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                ForEach(row.circulars) { item in
                    lockWidgetCard(for: item, expands: false)
                }
                ForEach(row.rectangulars) { item in
                    lockWidgetCard(for: item, expands: true)
                }
            }
        } else if !row.circulars.isEmpty {
            LazyVGrid(columns: Self.lockCircularColumns, alignment: .leading, spacing: 14) {
                ForEach(row.circulars) { item in
                    lockWidgetCard(for: item, expands: true)
                }
            }
        } else {
            LazyVGrid(columns: Self.lockRectangularColumns, alignment: .leading, spacing: 14) {
                ForEach(row.rectangulars) { item in
                    lockWidgetCard(for: item, expands: true)
                }
            }
        }
    }

    // MARK: Card chrome

    /// Premium widgets stay fully previewed in the gallery; paywall only on customize tap
    /// or when the user adds the widget on Home / Lock Screen (WidgetKit).
    private func requiresPremium(_ item: CourtifyWidgetCatalog.Item) -> Bool {
        !item.isFree && !isEntitled
    }

    private func openWidgetCustomization(for item: CourtifyWidgetCatalog.Item) {
        if requiresPremium(item) {
            showPaywall = true
        } else {
            CourtifyMotion.animateModal { shareItem = item }
        }
    }

    private func openColorCustomization(for item: CourtifyWidgetCatalog.Item) {
        // Always open the Customize sheet — favorite player pick lives here too
        // (free). Color actions inside the sheet still gate to Premium / paywall.
        colorPickerItem = item
    }

    private func galleryItem(id: String) -> CourtifyWidgetCatalog.Item? {
        CourtifyWidgetCatalog.item(id: id)
    }

    /// Lock Screen cards — accessory-sized widgets only (no purple container).
    @ViewBuilder
    private func lockWidgetCard(for item: CourtifyWidgetCatalog.Item, expands: Bool) -> some View {
        let isCircular = item.size == .small
        VStack(alignment: expands && isCircular ? .center : .leading, spacing: 8) {
            Button {
                openWidgetCustomization(for: item)
            } label: {
                WidgetGalleryPreview(
                    item: item,
                    favoritePlayer: favoritePlayer,
                    favoritePlayerID: favoritePlayerID,
                    tour: preferredTour,
                    payload: nil
                )
                .id("\(item.id)-\(colorRefreshTick)")
                .frame(maxWidth: expands && !isCircular ? .infinity : nil, alignment: .leading)
            }
            .courtifyButton(.card)

            Text(item.title)
                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(expands && isCircular ? .center : .leading)
        }
        .frame(
            maxWidth: expands ? .infinity : (isCircular ? 76 : nil),
            alignment: expands && isCircular ? .center : .leading
        )
    }

    @ViewBuilder
    private func widgetCard(for item: CourtifyWidgetCatalog.Item, fillsGridCell: Bool = false) -> some View {
        let isSquareSmall = item.size == .small
        let canRecolor = WidgetColorStyle.isCustomizable(item.id)
        let previewHeight = item.size.previewHeight
        let useSquareGridCell = isSquareSmall && fillsGridCell
        let showProBadge = requiresPremium(item)

        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Button {
                    openWidgetCustomization(for: item)
                } label: {
                    Group {
                        if useSquareGridCell {
                            WidgetGalleryPreview(
                                item: item,
                                favoritePlayer: favoritePlayer,
                                favoritePlayerID: favoritePlayerID,
                                tour: preferredTour,
                                payload: nil
                            )
                            .id("\(item.id)-\(colorRefreshTick)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                        } else {
                            WidgetGalleryPreview(
                                item: item,
                                favoritePlayer: favoritePlayer,
                                favoritePlayerID: favoritePlayerID,
                                tour: preferredTour,
                                payload: nil
                            )
                            .id("\(item.id)-\(colorRefreshTick)")
                            .frame(maxWidth: .infinity)
                            .frame(height: previewHeight)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .courtifyButton(.card)

                if showProBadge {
                    WidgetGalleryPremiumBadge()
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                if canRecolor {
                    Button {
                        openColorCustomization(for: item)
                    } label: {
                        WidgetCustomizeTag()
                    }
                    .courtifyButton(.ghost)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(maxWidth: .infinity)
            .modifier(WidgetGalleryPreviewFrame(square: useSquareGridCell, height: previewHeight))

            Text(item.title)
                .font(ThemeManager.roundedFont(.footnote, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Icon-only Customize control — paintbrush in a frosted circle (no label).
private struct WidgetCustomizeTag: View {
    var body: some View {
        Image(systemName: "paintbrush.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 24, height: 24)
            .background {
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    }
            }
            .accessibilityLabel("Customize")
    }
}

/// Text-only Premium chip for free users browsing Premium gallery cards.
private struct WidgetGalleryPremiumBadge: View {
    var body: some View {
        Text("Premium")
            .font(ThemeManager.roundedFont(size: 8, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
            }
            .accessibilityLabel("Premium")
    }
}

private struct WidgetGalleryPreviewFrame: ViewModifier {
    let square: Bool
    let height: CGFloat

    func body(content: Content) -> some View {
        if square {
            content.aspectRatio(1, contentMode: .fit)
        } else {
            content.frame(height: height)
        }
    }
}

#Preview {
    WidgetsCollectionView()
}
