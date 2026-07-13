import SwiftUI

struct WidgetsCollectionView: View {
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.userDefaults)
    private var favoritePlayerID = ""

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared

    @State private var selectedFilter = "All"
    @State private var showPaywall = false

    private let filters = ["All", "Small", "Medium", "Large"]

    private var favoritePlayer: TennisPlayer? {
        TennisPlayer.player(for: favoritePlayerID)
    }

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Widgets collection")
                        .font(ThemeManager.roundedFont(.title2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 56)

                    filterBar

                    widgetGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .onAppear { dataStore.refreshIfNeeded() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                favoritePlayerID: favoritePlayerID.isEmpty ? "sinner" : favoritePlayerID,
                onSubscribed: { showPaywall = false },
                onClose: { showPaywall = false },
                onSkip: { showPaywall = false }
            )
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        CourtifyMotion.animateSelection { selectedFilter = filter }
                    } label: {
                        Text(filter)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            widgetCard(
                title: "Next tournament",
                height: 160,
                isPro: false
            ) {
                nextTournamentPreview
            }

            widgetCard(
                title: "Favorite player",
                height: 160,
                isPro: false
            ) {
                favoritePlayerPreview
            }

            widgetCard(
                title: "Live scores",
                height: 160,
                isPro: true
            ) {
                liveScoresPreview
            }

            widgetCard(
                title: "Rankings",
                height: 160,
                isPro: false
            ) {
                rankingsPreview
            }

            widgetCard(
                title: "Order of play",
                height: 180,
                isPro: true,
                spanColumns: true
            ) {
                orderOfPlayPreview
            }
        }
    }

    private func widgetCard<Content: View>(
        title: String,
        height: CGFloat,
        isPro: Bool,
        spanColumns: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                content()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                if isPro, !revenueCat.isProUser, !AppGroupConstants.referralBypassActive {
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
                            if revenueCat.isProUser || AppGroupConstants.referralBypassActive || !isPro {
                                // Free widgets — no paywall
                            } else {
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

            Text(title)
                .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .gridCellColumns(spanColumns ? 2 : 1)
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
                Text("No live matches")
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
                        Text(match.player1.name)
                            .lineLimit(1)
                        Text("vs")
                            .foregroundStyle(.white.opacity(0.5))
                        Text(match.player2.name)
                            .lineLimit(1)
                    }
                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    WidgetsCollectionView()
}
