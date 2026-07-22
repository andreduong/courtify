import SwiftUI

struct HomeDashboardView: View {
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.appGroupStorage)
    private var favoritePlayerID = ""

    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared

    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showPlayerPicker = false
    @State private var now = Date()
    @State private var photoRefreshToken = 0
    @State private var showMediaUnavailableAlert = false
    @State private var showQuotaAlert = false

    private var hasFavoritePlayer: Bool {
        !favoritePlayerID.isEmpty
    }

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
        grandSlamMatching(nextGrandSlam)
    }

    private var liveRank: Int? {
        FavoritePlayerCatalog.displayRank(for: favoritePlayerID, payload: dataStore.payload)
    }

    var body: some View {
        // OLED black canvas; ambient glow lives in the player hero.
        // ScrollView is viewport-tall (no free scroll) so pull-to-refresh works
        // without changing the flex hero + fixed countdown layout.
        CourtifyFullBleedScreen { safeTop, size in
            ScrollView {
                VStack(spacing: 0) {
                    playerHeroSection(safeTop: safeTop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    grandSlamCountdownSection
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        // Breathing room above the floating tab bar (card used to
                        // sit flush against the capsule chrome).
                        .padding(.bottom, 10)
                }
                .frame(width: size.width, height: size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await dataStore.refresh()
                if dataStore.quotaExceededOnLastRefresh {
                    showQuotaAlert = true
                }
            }
            .tint(ThemeManager.opticYellow)
        }
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
        .sheet(isPresented: $showPlayerPicker) {
            FavoritePlayerPickerSheet(favoritePlayerID: $favoritePlayerID)
        }
        .alert("Player photo unavailable", isPresented: $showMediaUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We've hit today's tennis API photo limit. Your rank still shows from cache; the photo will load automatically once quota resets.")
        }
        .alert("API quota reached", isPresented: $showQuotaAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We've hit the Tennis API quota for now. Your last saved rankings are still shown.")
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
                    if hasFavoritePlayer, let player = favoritePlayer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(heroEyebrowText(for: player))
                                .font(ThemeManager.roundedFont(size: 11, weight: .bold))
                                .foregroundStyle(appearance.accentColor)
                                .tracking(1.6)

                            Text(player.name)
                                .font(ThemeManager.roundedFont(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                        }
                        .frame(maxWidth: 200, alignment: .leading)
                    }

                    Spacer(minLength: 8)

                    ProfileIconButton(showSettings: $showSettings)
                }
                .padding(.horizontal, 20)
                .padding(.top, safeTop + 10)

                if hasFavoritePlayer {
                    if showsFavoriteMediaHint {
                        Text("Photo unavailable (API limit). Rank still updates from cache.")
                            .font(ThemeManager.roundedFont(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    // Rank + record sit low; name stays high so it doesn't fight the torso.
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            if favoritePlayer?.isRetiredLegend == true {
                                // Retired greats: honor the career, never "Unranked".
                                Text("Legend")
                                    .font(ThemeManager.roundedFont(size: 34, weight: .bold))
                                    .foregroundStyle(ThemeManager.opticYellow)
                                    .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                            } else if let rank = liveRank {
                                Text("\(rank)")
                                    .font(WidgetTheme.displayFont(size: 92, weight: .heavy))
                                    .courtifyScoreboardNumber()
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                            } else if favoritePlayer?.isCustom == true {
                                // Genuinely unranked / inactive (rank heals on refresh otherwise) —
                                // labelled state beats a silent hole in the hero.
                                Text("Unranked")
                                    .font(ThemeManager.roundedFont(size: 30, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                            }

                            if let career = favoritePlayer?.careerRecord {
                                let total = career.wins + career.losses
                                let winRate = total > 0
                                    ? Int((Double(career.wins) / Double(total) * 100).rounded())
                                    : 0
                                Text(verbatim: "\(career.wins)–\(career.losses) career  ·  \(winRate)%")
                                    .font(ThemeManager.roundedFont(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.58))
                            } else if let record = favoritePlayer?.displaySeasonRecord {
                                let total = record.wins + record.losses
                                let winRate = total > 0
                                    ? Int((Double(record.wins) / Double(total) * 100).rounded())
                                    : 0
                                Text(verbatim: "\(record.wins)–\(record.losses)  ·  \(winRate)%")
                                    .font(ThemeManager.roundedFont(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.58))
                            } else if favoritePlayer?.isCustom == true {
                                Text(seasonRecordFallbackText)
                                    .font(ThemeManager.roundedFont(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: 180, alignment: .leading)

                        HStack(spacing: 4) {
                            LastUpdatedLabel(date: dataStore.lastUpdated)
                            if dataStore.lastUpdated != nil {
                                Text("· Pull down to refresh")
                                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    favoritePlayerEmptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func playerHeroBackground(safeTop: CGFloat) -> some View {
        ZStack {
            CourtifyAmbientGlow(
                primary: appearance.liftColor,
                secondary: appearance.accentColor,
                intensity: 1.15,
                anchor: .trailing
            )

            if let player = favoritePlayer {
                if player.bundledHeroCutoutName != nil {
                    // Bundled transparent torso cutout — full-bleed rectangular layout.
                    PlayerTorsoPhotoView(
                        player: player,
                        contentMode: .fit,
                        fadePortion: 0.25,
                        circularHeadshotSize: 156
                    )
                    .id("\(favoritePlayerID)-\(photoRefreshToken)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.top, safeTop + 28)
                    .padding(.leading, 96)
                    .padding(.trailing, 12)
                    .padding(.bottom, 48)
                } else {
                    // Custom favorites only have a circular studio headshot (or silhouette) —
                    // anchor it with a soft glow ring so the flex hero doesn't read as empty.
                    CustomFavoriteHeroPortrait(player: player, accent: appearance.accentColor)
                        .id("\(favoritePlayerID)-\(photoRefreshToken)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.top, safeTop + 24)
                        .padding(.trailing, 16)
                        .padding(.bottom, 72)
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Soften the flex-hero → countdown seam (clips otherwise leave a hard waist line).
            LinearGradient(
                colors: [.clear, ThemeManager.oledBlack.opacity(0.55), ThemeManager.oledBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        }
    }

    /// "ATP RANKING" reads wrong over a retired great — label the legend instead.
    private func heroEyebrowText(for player: TennisPlayer) -> String {
        let tour = player.tour == .wta ? "WTA" : "ATP"
        return player.isRetiredLegend ? "\(tour) LEGEND" : "\(tour) RANKING"
    }

    /// When the player's API id is known the record fills in on pull-to-refresh;
    /// otherwise (retired / unmatched) it is genuinely unavailable.
    private var seasonRecordFallbackText: String {
        guard let player = favoritePlayer else { return "" }
        if (PlayerRankCache.apiId(for: player.id) ?? 0) > 0 {
            return "Season record syncs on refresh"
        }
        return "Season record unavailable"
    }

    private var showsFavoriteMediaHint: Bool {
        guard let player = favoritePlayer, player.isCustom else { return false }
        guard FavoritePlayerEnricher.mediaFailureReason == .quota else { return false }
        return !PlayerPhotoStore.hasCachedPhotos(playerID: player.id)
    }

    private var favoritePlayerEmptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: "star.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(appearance.accentColor)

            Text("Pick your favorite player")
                .font(ThemeManager.roundedFont(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your #1 pick shows up here with live rank, season record, and hero photo.")
                .font(ThemeManager.roundedFont(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showPlayerPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Choose player")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(appearance.accentColor)
                .clipShape(Capsule())
            }
            .courtifyButton(.primary)
            .padding(.top, 4)

            HStack(spacing: 4) {
                LastUpdatedLabel(date: dataStore.lastUpdated)
                if dataStore.lastUpdated != nil {
                    Text("· Pull down to refresh")
                        .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Grand Slam countdown

    /// Brand palette for the countdown card — each major reads as its own event
    /// (USO night blue + yellow, AO sky blue + white, RG clay + green, Wimbledon
    /// green + lavender) instead of a generic glass tile.
    private var slamCardTheme: SlamCardTheme {
        switch nextSlam {
        case .usOpen:
            return SlamCardTheme(
                backdropTop: Color(hex: 0x17396A),
                backdropBottom: Color(hex: 0x081A33),
                accent: Color(hex: 0xFFD200),
                secondary: Color(hex: 0x8FB8E8)
            )
        case .australianOpen:
            return SlamCardTheme(
                backdropTop: Color(hex: 0x1273B0),
                backdropBottom: Color(hex: 0x0A3A5C),
                accent: Color(hex: 0xF5FBFF),
                secondary: Color(hex: 0x9AD1F5)
            )
        case .frenchOpen:
            return SlamCardTheme(
                backdropTop: Color(hex: 0xA6440F),
                backdropBottom: Color(hex: 0x5D2607),
                accent: Color(hex: 0x59B26A),
                secondary: Color(hex: 0xFFB27A)
            )
        case .wimbledon:
            return SlamCardTheme(
                backdropTop: Color(hex: 0x1E5B34),
                backdropBottom: Color(hex: 0x0F3520),
                accent: Color(hex: 0xC7A6F2),
                secondary: Color(hex: 0xA8D5B5)
            )
        case nil:
            return SlamCardTheme(
                backdropTop: ThemeManager.emeraldGreen.opacity(0.6),
                backdropBottom: ThemeManager.oledBlack,
                accent: ThemeManager.opticYellow,
                secondary: .white.opacity(0.5)
            )
        }
    }

    private var grandSlamCountdownSection: some View {
        let theme = slamCardTheme
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: 18, height: 3)
                    Text("NEXT GRAND SLAM")
                        .font(ThemeManager.roundedFont(size: 11, weight: .bold))
                        .foregroundStyle(theme.accent.opacity(0.95))
                        .tracking(1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let slam = nextGrandSlam {
                    Text(slam.name)
                        .font(ThemeManager.roundedFont(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("\(slam.location.uppercased())  ·  \(slam.surface.uppercased())")
                        .font(ThemeManager.roundedFont(size: 11, weight: .semibold))
                        .foregroundStyle(theme.secondary.opacity(0.85))
                        .tracking(1)

                    let countdown = TournamentCalendar.countdown(to: slam)
                    HStack(spacing: 18) {
                        countdownUnit(value: countdown.days, label: "DAYS", theme: theme)
                        countdownUnit(value: countdown.hours, label: "HRS", theme: theme)
                        countdownUnit(value: countdown.minutes, label: "MIN", theme: theme)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            if !revenueCat.isProUser, !AppGroupConstants.referralBypassActive {
                GetPremiumPill(action: { showPaywall = true })
                    // Never let the pill wrap "Get / Premium" — the leading copy
                    // scales down instead.
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                // Deep slam-brand wash over OLED black — one surface, one border.
                LinearGradient(
                    colors: [theme.backdropTop, theme.backdropBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [theme.accent.opacity(0.14), .clear],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: 260
                )

                CourtifyTennisBallWatermark()
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func countdownUnit(value: Int, label: String, theme: SlamCardTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%02d", value))
                .font(WidgetTheme.displayFont(size: 36, weight: .heavy))
                .courtifyScoreboardNumber()
                .foregroundStyle(.white)
                // The trailing Premium pill compresses this column — never let
                // a two-digit countdown wrap into a vertical stack.
                .fixedSize()
            Text(label)
                .font(WidgetTheme.microLabelFont(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .kerning(WidgetTheme.microLabelKerning)
                .foregroundStyle(theme.secondary.opacity(0.75))
        }
    }
}

private struct SlamCardTheme {
    let backdropTop: Color
    let backdropBottom: Color
    let accent: Color
    let secondary: Color
}

/// Hero treatment for custom favorites — a large circular studio headshot (or
/// silhouette) anchored by transparent radial washes so the flex hero space reads
/// as a deliberate portrait, not a small photo floating in emptiness.
private struct CustomFavoriteHeroPortrait: View {
    let player: TennisPlayer
    let accent: Color

    var body: some View {
        ZStack {
            // Transparent gradient washes only — never a fill behind a silhouette.
            RadialGradient(
                colors: [accent.opacity(0.16), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 170
            )

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            accent.opacity(0.5),
                            .white.opacity(0.08),
                            accent.opacity(0.18),
                            .white.opacity(0.05),
                            accent.opacity(0.5),
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 232, height: 232)

            PlayerTorsoPhotoView(
                player: player,
                circularHeadshotSize: 208,
                circularHeadshotAlignment: .center
            )
            .frame(width: 208, height: 208)
        }
        .frame(width: 264, height: 264)
    }
}

struct GetPremiumPill: View {
    let action: () -> Void
    @ObservedObject private var appearance = AppAppearanceStore.shared

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
                    colors: [appearance.liftColor, appearance.liftColor.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(appearance.accentColor.opacity(0.25), lineWidth: 1)
            }
        }
        .courtifyButton(.ghost)
    }
}

#Preview {
    HomeDashboardView()
}
