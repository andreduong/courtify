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
    @State private var photoRefreshToken = 0
    @State private var showMediaUnavailableAlert = false

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var favoritePlayer: TennisPlayer? {
        FavoritePlayerCatalog.resolvedPlayer(id: favoritePlayerID, payload: dataStore.payload)
    }

    private var selectedTour: TourPreference {
        guard let pref = TourPreference(rawValue: tourPreferenceRaw) else { return .atp }
        return pref == .wta ? .wta : .atp
    }

    private var nextGrandSlam: TournamentEvent? {
        TournamentCalendar.nextGrandSlam(for: selectedTour)
    }

    private var nextSlam: GrandSlam? {
        nextGrandSlam?.grandSlam
    }

    private var liveRank: Int? {
        FavoritePlayerCatalog.displayRank(for: favoritePlayerID, payload: dataStore.payload)
    }

    private var slamHighlight: Color {
        guard let slam = nextSlam else { return ThemeManager.opticYellow }
        return Color(hex: slam.highlightColor)
    }

    private var slamBase: Color {
        guard let slam = nextSlam else { return ThemeManager.midnightGreen }
        switch slam {
        case .australianOpen: return Color(hex: 0x08263D)
        case .frenchOpen: return Color(hex: 0x3B1404)
        case .wimbledon: return Color(hex: 0x140B22)
        case .usOpen: return Color(hex: 0x07111F)
        }
    }

    private var slamLift: Color {
        guard let slam = nextSlam else { return ThemeManager.emeraldGreen.opacity(0.35) }
        switch slam {
        case .australianOpen: return Color(hex: 0x0E4A72)
        case .frenchOpen: return Color(hex: 0x8A2E05)
        case .wimbledon: return Color(hex: 0x2A1848)
        case .usOpen: return Color(hex: 0x0C2340)
        }
    }

    var body: some View {
        // Slam canvas bleeds under the translucent tab bar + home indicator.
        CourtifyFullBleedScreen(canvasColor: slamBase) { safeTop, size in
            VStack(spacing: 0) {
                playerHeroSection(safeTop: safeTop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Content-sized band; slam `canvasColor` bleeds under the tab bar.
                grandSlamCountdownSection
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        // Solid slam chrome on Home so brand color fills behind + below the tab bar.
        .toolbarBackground(slamBase, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            dataStore.loadCachedPayload()
            #if DEBUG
            if UITestLaunchArgs.showsSettings {
                showSettings = true
            }
            #endif
        }
        .task(id: favoritePlayerID) {
            await FavoritePlayerEnricher.ensureLoaded(
                playerID: favoritePlayerID,
                payload: dataStore.payload
            )
            guard !showSettings, !showPaywall else { return }
            if FavoritePlayerEnricher.mediaUnavailable,
               FavoritePlayerEnricher.shouldPresentMediaUnavailableAlert(for: favoritePlayerID) {
                FavoritePlayerEnricher.markMediaUnavailableAlertPresented(for: favoritePlayerID)
                showMediaUnavailableAlert = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.favoritePlayerDidChange)) { _ in
            photoRefreshToken += 1
            dataStore.loadCachedPayload()
        }
        .onReceive(timer) { now = $0 }
        .settingsSheet(isPresented: $showSettings)
        .alert("Player photo unavailable", isPresented: $showMediaUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We've hit today's tennis API photo limit. Your rank still shows from cache; the photo will load automatically once quota resets.")
        }
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

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedTour == .wta ? "WTA RANKING" : "ATP RANKING")
                            .font(ThemeManager.roundedFont(size: 11, weight: .bold))
                            .foregroundStyle(ThemeManager.opticYellow)
                            .tracking(1.6)

                        if let player = favoritePlayer {
                            Text(player.name)
                                .font(ThemeManager.roundedFont(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                        }
                    }
                    .frame(maxWidth: 200, alignment: .leading)

                    Spacer(minLength: 8)

                    ProfileIconButton(showSettings: $showSettings)
                }
                .padding(.horizontal, 20)
                .padding(.top, safeTop + 10)

                if showsFavoriteMediaHint {
                    Text("Photo & season record unavailable (API limit). Rank still updates from cache.")
                        .font(ThemeManager.roundedFont(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Rank + record sit low; name stays high so it doesn't fight the torso.
                VStack(alignment: .leading, spacing: 6) {
                    if let rank = liveRank {
                        Text("\(rank)")
                            .font(WidgetTheme.displayFont(size: 92, weight: .black))
                            .fontWidth(.compressed)
                            .foregroundStyle(.white)
                            .tracking(-5)
                            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                    }

                    if let record = favoritePlayer?.displaySeasonRecord {
                        let total = record.wins + record.losses
                        let winRate = total > 0
                            ? Int((Double(record.wins) / Double(total) * 100).rounded())
                            : 0
                        Text(verbatim: "\(record.wins)–\(record.losses)  ·  \(winRate)%")
                            .font(ThemeManager.roundedFont(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    } else if favoritePlayer?.isCustom == true {
                        Text("Season record unavailable")
                            .font(ThemeManager.roundedFont(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.leading, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: 180, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func playerHeroBackground(safeTop: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x1F7A4A),
                    ThemeManager.emeraldGreen,
                    Color(hex: 0x0C2A1A),
                    ThemeManager.midnightGreen,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    ThemeManager.opticYellow.opacity(0.08),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .center
            )

            if let player = favoritePlayer {
                PlayerTorsoPhotoView(player: player, contentMode: .fit)
                    .id("\(favoritePlayerID)-\(photoRefreshToken)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.top, safeTop + 28)
                    .padding(.leading, 96)
                    .padding(.trailing, -24)
                    .padding(.bottom, 4)
            }
        }
    }

    private var showsFavoriteMediaHint: Bool {
        guard let player = favoritePlayer, player.isCustom else { return false }
        if FavoritePlayerEnricher.mediaUnavailable { return true }
        return player.displaySeasonRecord == nil
            && !PlayerPhotoStore.hasCachedPhotos(playerID: player.id)
    }

    // MARK: - Grand Slam countdown

    private var grandSlamCountdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            slamHighlight.opacity(0.9),
                            slamHighlight.opacity(0.3),
                            .white.opacity(0.06),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(slamHighlight)
                            .frame(width: 18, height: 3)
                        Text("NEXT GRAND SLAM")
                            .font(ThemeManager.roundedFont(size: 11, weight: .bold))
                            .foregroundStyle(slamHighlight.opacity(0.95))
                            .tracking(1.5)
                    }

                    if let slam = nextGrandSlam {
                        Text(slam.name)
                            .font(ThemeManager.roundedFont(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(slam.location.uppercased())  ·  \(slam.surface.uppercased())")
                            .font(ThemeManager.roundedFont(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.42))
                            .tracking(1)

                        let countdown = TournamentCalendar.countdown(to: slam)
                        HStack(spacing: 18) {
                            countdownUnit(value: countdown.days, label: "DAYS")
                            countdownUnit(value: countdown.hours, label: "HRS")
                            countdownUnit(value: countdown.minutes, label: "MIN")
                        }
                        .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)

                if !revenueCat.isProUser, !AppGroupConstants.referralBypassActive {
                    GetPremiumPill(action: { showPaywall = true })
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { grandSlamBackground }
    }

    private var grandSlamBackground: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [slamLift, slamBase],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(slamHighlight)
                .frame(width: 3)
                .opacity(0.9)

            if let slam = nextSlam {
                AssetCatalogImage(name: slam.logoImageName, contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .opacity(0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, -12)
                    .padding(.bottom, -16)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(format: "%02d", value))
                .font(WidgetTheme.displayFont(size: 36, weight: .heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(ThemeManager.roundedFont(size: 10, weight: .bold))
                .foregroundStyle(slamHighlight.opacity(0.8))
                .tracking(1.3)
        }
    }
}

// MARK: - Tournament → Grand Slam

private extension TournamentEvent {
    var grandSlam: GrandSlam? {
        guard tier == .grandSlam else { return nil }
        return GrandSlam.allCases.first {
            name.localizedCaseInsensitiveContains($0.rawValue)
                || (shortName == "AO" && $0 == .australianOpen)
                || (shortName == "RG" && $0 == .frenchOpen)
                || (shortName == "WIM" && $0 == .wimbledon)
                || (shortName == "USO" && $0 == .usOpen)
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
