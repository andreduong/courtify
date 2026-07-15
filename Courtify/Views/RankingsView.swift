import SwiftUI

struct RankingsView: View {
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @State private var selectedTour: TourPreference = .atp
    @State private var showSettings = false

    private var rankings: [WidgetRankingEntry] {
        dataStore.rankings(for: selectedTour)
    }

    private var leader: WidgetRankingEntry? {
        rankings.first
    }

    var body: some View {
        CourtifyHeroScrollScreen(
            heroHeight: CourtifyLayout.rankingsHeroHeight,
            heroBackground: { heroBackground },
            heroContent: { heroContent },
            listContent: { rankingsListContent }
        )
        .refreshable {
            await dataStore.refresh()
        }
        .tint(ThemeManager.opticYellow)
        .onAppear {
            if let pref = TourPreference(rawValue: tourPreferenceRaw), pref != .both {
                selectedTour = pref == .wta ? .wta : .atp
            }
            // Cache only — live data refreshes exclusively on pull-to-refresh.
            dataStore.loadCachedPayload()
        }
        .settingsSheet(isPresented: $showSettings)
    }

    // MARK: - Hero

    private var heroBackground: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [
                    ThemeManager.emeraldGreen.opacity(0.95),
                    ThemeManager.emeraldGreen.opacity(0.5),
                    ThemeManager.midnightGreen,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let leader, let bundled = bundledPlayer(for: leader) {
                CachedBundledImage(name: bundled.heroImageName, contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 260, alignment: .bottomTrailing)
                    .padding(.trailing, 8)
                    .opacity(0.92)
            }
        }
    }

    @ViewBuilder
    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("\(selectedTour.rawValue) Rankings")
                    .font(ThemeManager.roundedFont(.title3, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                TourPillToggle(selectedTour: $selectedTour)

                ProfileIconButton(showSettings: $showSettings)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                if let leader {
                    Text("World No. 1")
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(ThemeManager.opticYellow)

                    Text(leader.player.name)
                        .font(ThemeManager.roundedFont(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: 220, alignment: .leading)
                }

                HStack(spacing: 4) {
                    LastUpdatedLabel(date: dataStore.lastUpdated)
                    if dataStore.lastUpdated != nil {
                        Text("· Pull down to refresh")
                            .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - List tiles

    @ViewBuilder
    private var rankingsListContent: some View {
        if rankings.isEmpty {
            VStack(spacing: 12) {
                if dataStore.isLoading {
                    ProgressView()
                        .tint(ThemeManager.opticYellow)
                } else {
                    PullToRefreshHint(message: "Pull down to load \(selectedTour.rawValue) rankings")

                    if let error = dataStore.lastError {
                        Text(error)
                            .font(ThemeManager.roundedFont(.caption))
                            .foregroundStyle(ThemeManager.opticYellow.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ForEach(Array(rankings.enumerated()), id: \.element.id) { index, entry in
                VStack(spacing: 0) {
                    RankingTile(rank: entry.rank ?? index + 1, entry: entry)
                    CourtifyTileDivider()
                }
            }
        }
    }

    private func bundledPlayer(for entry: WidgetRankingEntry) -> TennisPlayer? {
        TennisPlayer.topPlayers.first {
            $0.name.caseInsensitiveCompare(entry.player.name) == .orderedSame
        }
    }
}

private struct RankingTile: View {
    let rank: Int
    let entry: WidgetRankingEntry

    var body: some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", rank))
                .font(ThemeManager.roundedFont(.title3, weight: .bold))
                .foregroundStyle(.white.opacity(rank <= 3 ? 1 : 0.55))
                .frame(width: 44, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.player.name)
                    .font(ThemeManager.roundedFont(.headline, weight: .bold))
                    .foregroundStyle(.white)

                if let country = entry.player.country {
                    Text(country)
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(ThemeManager.courtGreen)
                }
            }

            Spacer(minLength: 8)

            if let points = entry.points {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(points.formatted())
                        .font(ThemeManager.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(.white)
                    Text("PTS")
                        .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    RankingsView()
}
