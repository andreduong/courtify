import SwiftUI

private enum WidgetGallerySize: String, CaseIterable, Identifiable {
    case all = "All"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var previewHeight: CGFloat {
        switch self {
        case .all, .medium: 160
        case .small: 120
        case .large: 220
        }
    }
}

private struct WidgetGalleryItem: Identifiable {
    let id: String
    let title: String
    let size: WidgetGallerySize
    let isPro: Bool
    let spansFullWidth: Bool
}

struct WidgetsCollectionView: View {
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.userDefaults)
    private var favoritePlayerID = ""

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared

    @State private var selectedFilter: WidgetGallerySize = .all
    @State private var showPaywall = false

    private var favoritePlayer: TennisPlayer? {
        TennisPlayer.player(for: favoritePlayerID)
    }

    private let catalog: [WidgetGalleryItem] = [
        WidgetGalleryItem(id: "next", title: "Next tournament", size: .medium, isPro: false, spansFullWidth: false),
        WidgetGalleryItem(id: "favorite", title: "Favorite player", size: .medium, isPro: false, spansFullWidth: false),
        WidgetGalleryItem(id: "live", title: "Live scores", size: .small, isPro: true, spansFullWidth: false),
        WidgetGalleryItem(id: "rankings", title: "Rankings", size: .small, isPro: false, spansFullWidth: false),
        WidgetGalleryItem(id: "order", title: "Order of play", size: .large, isPro: true, spansFullWidth: true),
    ]

    private var visibleItems: [WidgetGalleryItem] {
        guard selectedFilter != .all else { return catalog }
        return catalog.filter { $0.size == selectedFilter }
    }

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Widgets collection")
                            .font(ThemeManager.roundedFont(.title2, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, CourtifyLayout.topSafeInset + 8)

                        LastUpdatedLabel(date: dataStore.lastUpdated)
                    }

                    filterBar
                    widgetGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
                .animation(CourtifyMotion.selection, value: selectedFilter)
            }
            .refreshable {
                await dataStore.refresh()
            }
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
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WidgetGallerySize.allCases) { filter in
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
    }

    private var widgetGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 16
        ) {
            if visibleItems.isEmpty {
                Text("No \(selectedFilter.rawValue.lowercased()) widgets in this collection")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.55))
                    .gridCellColumns(2)
                    .padding(.vertical, 24)
            } else {
                ForEach(visibleItems) { item in
                    widgetCard(for: item)
                        .gridCellColumns(item.spansFullWidth ? 2 : 1)
                }
            }
        }
    }

    private func previewHeight(for item: WidgetGalleryItem) -> CGFloat {
        selectedFilter == .all ? item.size.previewHeight : selectedFilter.previewHeight
    }

    @ViewBuilder
    private func widgetCard(for item: WidgetGalleryItem) -> some View {
        let height = previewHeight(for: item)
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                previewContent(for: item)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                if item.isPro, !revenueCat.isProUser, !AppGroupConstants.referralBypassActive {
                    Text("PRO 🎾")
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(10)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if item.isPro, !revenueCat.isProUser, !AppGroupConstants.referralBypassActive {
                                showPaywall = true
                            }
                        } label: {
                            Text("Customize 🖌️")
                                .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .courtifyButton(.ghost)
                        .padding(10)
                    }
                }
            }

            HStack {
                Text(item.title)
                    .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if selectedFilter == .all {
                    Text(item.size.rawValue)
                        .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    @ViewBuilder
    private func previewContent(for item: WidgetGalleryItem) -> some View {
        switch item.id {
        case "next": nextTournamentPreview
        case "favorite": favoritePlayerPreview
        case "live": liveScoresPreview
        case "rankings": rankingsPreview
        case "order": orderOfPlayPreview
        default: EmptyView()
        }
    }

    private var nextTournamentPreview: some View {
        let event = TournamentCalendar.nextMajor(for: .atp)
        return ZStack {
            LinearGradient(colors: [Color(hex: 0xE35205), Color(hex: 0x0A120D)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                if let event {
                    Text("\(event.shortName) · \(event.location.uppercased())")
                        .font(ThemeManager.roundedFont(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(event.dateRangeLabel)
                        .font(ThemeManager.roundedFont(.title2, weight: .bold))
                        .foregroundStyle(.white)
                    Text("2026")
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var favoritePlayerPreview: some View {
        ZStack {
            LinearGradient(colors: [ThemeManager.emeraldGreen, ThemeManager.midnightGreen], startPoint: .top, endPoint: .bottom)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1st")
                        .font(ThemeManager.roundedFont(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                    Text(favoritePlayer?.name ?? "Your player")
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer()
                if let player = favoritePlayer {
                    CachedBundledImage(name: player.resolvedImageName, contentMode: .fit)
                        .frame(width: 80)
                }
            }
            .padding(16)
        }
    }

    private var liveScoresPreview: some View {
        ZStack {
            Color.black.opacity(0.35)
            if let match = dataStore.payload?.liveMatches.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIVE")
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)
                    Text(match.player1.name)
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("vs \(match.player2.name)")
                        .font(ThemeManager.roundedFont(.caption2))
                        .foregroundStyle(.white.opacity(0.7))
                    if let score = match.score {
                        Text(score)
                            .font(ThemeManager.roundedFont(.headline, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Pull to refresh")
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .background {
            CachedBundledImage(name: "slam-wimbledon", contentMode: .fill)
                .blur(radius: 12)
        }
    }

    private var rankingsPreview: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0085CA), ThemeManager.midnightGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                Text("ATP Top 3")
                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(dataStore.rankings(for: .atp).prefix(3)) { entry in
                    Text("\(entry.rank ?? 0). \(entry.player.name)")
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if dataStore.rankings(for: .atp).isEmpty {
                    Text("Pull to refresh")
                        .font(ThemeManager.roundedFont(.caption2))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var orderOfPlayPreview: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [ThemeManager.midnightGreen, Color(hex: 0x0C2340)], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                Text("Centre Court")
                    .font(ThemeManager.roundedFont(.caption, weight: .bold))
                    .foregroundStyle(ThemeManager.opticYellow)
                ForEach((dataStore.payload?.upcomingMatches ?? []).prefix(3)) { match in
                    HStack {
                        Text(match.player1.name).lineLimit(1)
                        Text("vs").foregroundStyle(.white.opacity(0.5))
                        Text(match.player2.name).lineLimit(1)
                    }
                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
                if dataStore.payload?.upcomingMatches.isEmpty != false {
                    Text("Pull to refresh")
                        .font(ThemeManager.roundedFont(.caption2))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    WidgetsCollectionView()
}
