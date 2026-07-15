import SwiftUI

struct HomeDashboardView: View {
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.appGroupStorage)
    private var favoritePlayerID = ""

    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared

    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var favoritePlayer: TennisPlayer? {
        TennisPlayer.player(for: favoritePlayerID)
    }

    private var selectedTour: TourPreference {
        guard let pref = TourPreference(rawValue: tourPreferenceRaw) else { return .atp }
        return pref == .wta ? .wta : .atp
    }

    private var nextGrandSlam: TournamentEvent? {
        TournamentCalendar.nextGrandSlam(for: selectedTour)
    }

    private var liveRank: Int? {
        if let payload = dataStore.payload,
           let resolved = FavoritePlayerResolver.ranking(for: payload) {
            return resolved.rank
        }
        return favoritePlayer?.ranking
    }

    var body: some View {
        CourtifyFullBleedScreen { safeTop, size in
            VStack(spacing: 0) {
                // Hero flexes to fill whatever the countdown section doesn't need,
                // so the player name always sits directly above "Next Grand Slam".
                playerHeroSection(safeTop: safeTop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                grandSlamCountdownSection
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .onAppear {
            // Cache only — live data refreshes exclusively on pull-to-refresh
            // (Rankings/Widgets tabs) to keep API usage minimal.
            dataStore.loadCachedPayload()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UITestSettings") {
                showSettings = true
            }
            #endif
        }
        .onReceive(timer) { now = $0 }
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
    }

    // MARK: - Player hero

    private func playerHeroSection(safeTop: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            playerHeroBackground(safeTop: safeTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            heroSeamGradient

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Spacer()

                    ProfileIconButton(showSettings: $showSettings)
                }
                .padding(.horizontal, 20)
                .padding(.top, safeTop + 8)

                Spacer(minLength: 0)

                playerStatsBlock
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func playerHeroBackground(safeTop: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [ThemeManager.emeraldGreen.opacity(0.55), ThemeManager.midnightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let player = favoritePlayer {
                CachedBundledImage(name: player.heroImageName, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.top, safeTop + 8)

                Text(player.name.split(separator: " ").first.map(String.init) ?? player.name)
                    .font(ThemeManager.roundedFont(size: 96, weight: .bold))
                    .foregroundStyle(.white.opacity(0.08))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 16)
                    .padding(.top, safeTop + 48)
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.25),
                    .clear,
                    .black.opacity(0.45),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var heroSeamGradient: some View {
        VStack(spacing: 0) {
            Spacer()
            LinearGradient(
                colors: [
                    .clear,
                    ThemeManager.emeraldGreen.opacity(0.25),
                    ThemeManager.midnightGreen.opacity(0.85),
                    ThemeManager.midnightGreen,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
        .allowsHitTesting(false)
    }

    private var playerStatsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                statChip(icon: "chart.bar.fill", label: "Rank", value: rankLabel)
                if let record = favoritePlayer?.seasonRecord {
                    statChip(
                        icon: "sportscourt.fill",
                        label: "2026",
                        value: "\(record.wins)-\(record.losses)"
                    )
                }
            }

            if let rank = liveRank {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(rank)")
                        .font(ThemeManager.roundedFont(size: 58, weight: .bold))
                        .foregroundStyle(.white)
                    Text("RANK")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 8)
                }
            }

            if let player = favoritePlayer {
                Text(player.name)
                    .font(ThemeManager.roundedFont(.title2, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rankLabel: String {
        if let rank = liveRank {
            return "#\(rank)"
        }
        return "—"
    }

    private func statChip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
            Text(value)
                .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Grand Slam countdown

    private var grandSlamCountdownSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Grand Slam")
                    .font(ThemeManager.roundedFont(.title2, weight: .bold))
                    .foregroundStyle(.white)

                if let slam = nextGrandSlam {
                    Text("\(slam.name) · Starts in")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))

                    let countdown = TournamentCalendar.countdown(to: slam)
                    HStack(spacing: 12) {
                        countdownUnit(value: countdown.days, label: "D")
                        countdownUnit(value: countdown.hours, label: "H")
                        countdownUnit(value: countdown.minutes, label: "M")
                    }
                    .padding(.top, 2)

                    Text("Follow every match from draw day through the trophy ceremony.")
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if !revenueCat.isProUser {
                GetPremiumPill(action: { showPaywall = true })
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { grandSlamBackground }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
    }

    private var grandSlamBackground: some View {
        // Base color is flexible, so it adopts the section's exact size; the
        // overlays (blurred slam photo can be much taller) are then clipped to it.
        ThemeManager.midnightGreen
            .overlay {
                if let slam = nextGrandSlam, let imageName = slam.heroImageName {
                    CachedBundledImage(name: imageName, contentMode: .fill)
                        .blur(radius: 14)
                        .scaleEffect(1.1)
                        .opacity(0.28)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [
                        ThemeManager.midnightGreen,
                        ThemeManager.emeraldGreen.opacity(0.16),
                        ThemeManager.midnightGreen,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay { bottomSeamGradient }
            .clipped()
    }

    private var bottomSeamGradient: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    ThemeManager.midnightGreen,
                    ThemeManager.emeraldGreen.opacity(0.2),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(ThemeManager.roundedFont(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

struct GetPremiumPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                Text("Get Premium")
                    .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [ThemeManager.emeraldGreen, ThemeManager.emeraldGreen.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(ThemeManager.opticYellow.opacity(0.25), lineWidth: 1)
            }
        }
        .courtifyButton(.ghost)
    }
}

#Preview {
    HomeDashboardView()
}
