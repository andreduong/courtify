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

    var body: some View {
        ZStack(alignment: .top) {
            ThemeManager.midnightGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    rankingsList
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack {
                HStack {
                    TourPillToggle(selectedTour: $selectedTour)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, CourtifyLayout.topSafeInset + 8)
                Spacer()
            }
        }
        .onAppear {
            if let pref = TourPreference(rawValue: tourPreferenceRaw), pref != .both {
                selectedTour = pref == .wta ? .wta : .atp
            }
            dataStore.refreshIfNeeded()
        }
        .onChange(of: selectedTour) { _, _ in
            dataStore.refreshIfNeeded()
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if let leader {
            ZStack(alignment: .bottomLeading) {
                heroBackground(for: leader)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ordinalRank(leader.rank ?? 1))
                            .font(ThemeManager.roundedFont(size: 52, weight: .bold))
                            .foregroundStyle(.white)

                        if let points = leader.points {
                            Text("\(points)pts")
                                .font(ThemeManager.roundedFont(.title3, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Text(leader.player.name)
                            .font(ThemeManager.roundedFont(.headline, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))

                        if let country = leader.player.country {
                            Text(country)
                                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    Spacer()

                    playerPortrait(for: leader, fullBody: true)
                        .frame(width: 160, height: 240)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .frame(height: 340)
        } else if dataStore.isLoading {
            ProgressView()
                .tint(ThemeManager.opticYellow)
                .frame(height: 340)
        }
    }

    private var rankingsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rankings.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    RankingRow(rank: entry.rank ?? index + 1, entry: entry)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 100)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: -24)
    }

    @ViewBuilder
    private func heroBackground(for leader: WidgetRankingEntry) -> some View {
        ZStack {
            if let bundled = bundledPlayer(for: leader) {
                CachedBundledImage(name: bundled.paywallImageName, contentMode: .fill)
                    .blur(radius: 28)
                    .scaleEffect(1.15)
            } else {
                LinearGradient(
                    colors: [ThemeManager.emeraldGreen.opacity(0.7), ThemeManager.midnightGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            Color.black.opacity(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func playerPortrait(for entry: WidgetRankingEntry, fullBody: Bool) -> some View {
        if let bundled = bundledPlayer(for: entry) {
            CachedBundledImage(name: fullBody ? bundled.resolvedImageName : bundled.resolvedImageName, contentMode: .fit)
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

            VStack(alignment: .trailing, spacing: 2) {
                if let points = entry.points {
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
