import SwiftUI

struct RankingsView: View {
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @State private var selectedTour: TourPreference = .atp

    private var rankings: [WidgetRankingEntry] {
        dataStore.rankings(for: selectedTour)
    }

    private var leader: WidgetRankingEntry? {
        rankings.first
    }

    private var restOfRankings: [WidgetRankingEntry] {
        Array(rankings.dropFirst())
    }

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    rankingsList
                }
            }
            .refreshable {
                await dataStore.refresh()
            }
        }
        .onAppear {
            if let pref = TourPreference(rawValue: tourPreferenceRaw), pref != .both {
                selectedTour = pref == .wta ? .wta : .atp
            }
            dataStore.loadCachedPayload()
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            if let leader {
                heroBackground(for: leader)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TourPillToggle(selectedTour: $selectedTour)
                        Spacer()
                    }
                    .padding(.top, CourtifyLayout.topSafeInset + 8)

                    Spacer(minLength: 12)

                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            LastUpdatedLabel(date: dataStore.lastUpdated)

                            Text(ordinalRank(leader.rank ?? 1))
                                .font(ThemeManager.roundedFont(size: 48, weight: .bold))
                                .foregroundStyle(.white)

                            if let points = leader.points {
                                Text("\(points) pts")
                                    .font(ThemeManager.roundedFont(.title3, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                            }

                            Text(leader.player.name)
                                .font(ThemeManager.roundedFont(.headline, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)

                            if let country = leader.player.country {
                                Text(country)
                                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        playerPortrait(for: leader)
                            .frame(width: 130, height: 220)
                            .offset(y: 12)
                    }
                    .padding(.bottom, 44)
                }
                .padding(.horizontal, 24)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        TourPillToggle(selectedTour: $selectedTour)
                        Spacer()
                    }
                    .padding(.top, CourtifyLayout.topSafeInset + 8)

                    LastUpdatedLabel(date: dataStore.lastUpdated)
                    PullToRefreshHint(message: "Pull down to load \(selectedTour.rawValue) rankings")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .frame(height: 320)
            }
        }
        .frame(height: leader == nil ? 320 : 400)
    }

    private var rankingsList: some View {
        VStack(spacing: 0) {
            if dataStore.isLoading, rankings.isEmpty {
                ProgressView()
                    .tint(ThemeManager.opticYellow)
                    .padding(.vertical, 40)
            } else if restOfRankings.isEmpty, leader != nil {
                Text("No additional rankings loaded")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.gray)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(restOfRankings.enumerated()), id: \.element.id) { index, entry in
                    RankingRow(rank: entry.rank ?? index + 2, entry: entry)
                }
            }

            if let error = dataStore.lastError, rankings.isEmpty {
                Text(error)
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding()
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 120)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        }
        .offset(y: leader == nil ? 0 : -16)
    }

    @ViewBuilder
    private func heroBackground(for leader: WidgetRankingEntry) -> some View {
        ZStack {
            if let bundled = bundledPlayer(for: leader) {
                CachedBundledImage(name: bundled.paywallImageName, contentMode: .fill)
                    .blur(radius: 24)
                    .scaleEffect(1.08)
            } else {
                LinearGradient(
                    colors: [ThemeManager.emeraldGreen.opacity(0.7), ThemeManager.midnightGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func playerPortrait(for entry: WidgetRankingEntry) -> some View {
        if let bundled = bundledPlayer(for: entry) {
            CachedBundledImage(name: bundled.resolvedImageName, contentMode: .fit)
        } else if let url = entry.player.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                default:
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func bundledPlayer(for entry: WidgetRankingEntry) -> TennisPlayer? {
        TennisPlayer.topPlayers.first {
            $0.name.caseInsensitiveCompare(entry.player.name) == .orderedSame
        }
    }

    private func ordinalRank(_ rank: Int) -> String {
        let mod100 = rank % 100
        let mod10 = rank % 10
        let suffix: String
        if (11 ... 13).contains(mod100) {
            suffix = "th"
        } else {
            switch mod10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(rank)\(suffix)"
    }
}

private struct RankingRow: View {
    let rank: Int
    let entry: WidgetRankingEntry

    var body: some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", rank))
                .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 36, height: 36)
                .background(Circle().strokeBorder(Color.gray.opacity(0.2), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.player.name)
                    .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                    .foregroundStyle(ThemeManager.midnightGreen)

                if let country = entry.player.country {
                    Text(country)
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            if let points = entry.points {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(points)")
                        .font(ThemeManager.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(ThemeManager.midnightGreen)
                    Text("pts")
                        .font(ThemeManager.roundedFont(.caption2))
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    RankingsView()
}
