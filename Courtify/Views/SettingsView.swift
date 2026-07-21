import SwiftUI
import StoreKit

// MARK: - Profile entry point (shared by all tabs)

/// Top-right profile button that opens Settings. Use this on every tab so the
/// entry point looks and behaves identically across screens.
struct ProfileIconButton: View {
    @Binding var showSettings: Bool

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
        }
        .courtifyButton(.icon)
        .accessibilityLabel("Profile")
    }
}

extension View {
    /// Attach the Settings sheet once per tab screen.
    func settingsSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            SettingsView()
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.appGroupStorage)
    private var favoritePlayerID = ""

    @AppStorage(AppGroupConstants.Keys.favoriteGrandSlam, store: AppGroupConstants.appGroupStorage)
    private var favoriteGrandSlamRaw = ""

    @AppStorage("use24HourFormat", store: AppGroupConstants.appGroupStorage)
    private var use24HourFormat = false

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared

    @State private var showPlayerPicker = false
    @State private var showSlamPicker = false
    @State private var showPaywall = false
    @State private var showThemePicker = false
    @State private var showBallPicker = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private var favoritePlayer: TennisPlayer? {
        FavoritePlayerCatalog.resolvedPlayer(id: favoritePlayerID, payload: dataStore.payload)
    }

    private var favoriteSlam: GrandSlam? {
        GrandSlam(rawValue: favoriteGrandSlamRaw)
    }

    private var isEntitled: Bool {
        revenueCat.isProUser || AppGroupConstants.referralBypassActive
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v.\(version)"
    }

    private var timeZoneLabel: String {
        let seconds = TimeZone.current.secondsFromGMT()
        let hours = seconds / 3600
        return hours >= 0 ? "GMT+\(hours)" : "GMT\(hours)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    favoritesSection
                    personalSection
                    appearanceSection
                    helpSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(ThemeManager.oledBlack.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(9)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
                            }
                    }
                    .courtifyButton(.icon)
                }
            }
            .toolbarBackground(ThemeManager.oledBlack, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            dataStore.loadCachedPayload()
        }
        .task {
            await FavoritePlayerEnricher.ensureLoaded(
                playerID: favoritePlayerID,
                payload: dataStore.payload
            )
        }
        .sheet(isPresented: $showPlayerPicker) {
            FavoritePlayerPickerSheet(favoritePlayerID: $favoritePlayerID)
        }
        .sheet(isPresented: $showSlamPicker) {
            FavoriteSlamPickerSheet(selectedRaw: $favoriteGrandSlamRaw)
        }
        .sheet(isPresented: $showThemePicker) {
            AppThemePickerSheet()
        }
        .sheet(isPresented: $showBallPicker) {
            LogoBallPickerSheet()
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
        .alert("Restore Purchases", isPresented: .init(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Your favorites")

            HStack(spacing: 14) {
                FavoriteCard(
                    title: favoritePlayer?.name.uppercased() ?? "PICK A PLAYER",
                    subtitle: favoritePlayer == nil ? "Fav player" : nil,
                    action: { showPlayerPicker = true }
                ) {
                    if let player = favoritePlayer {
                        PlayerTorsoPhotoView(player: player, contentMode: .fit)
                            .frame(width: 92, height: 108)
                            .opacity(0.55)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)

                FavoriteCard(
                    title: favoriteSlam?.rawValue.uppercased() ?? "PICK A SLAM",
                    subtitle: favoriteSlam == nil ? "Fav Grand Slam" : nil,
                    action: { showSlamPicker = true }
                ) {
                    if let slam = favoriteSlam {
                        FavoriteSlamLogoBadge(slam: slam)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }

            if showsFavoriteMediaHint {
                Text("Player photo isn’t available right now (daily API limit). Rank still updates from cache — photo retries automatically later.")
                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showsFavoriteMediaHint: Bool {
        guard let player = favoritePlayer, player.isCustom else { return false }
        return !PlayerPhotoStore.hasCachedPhotos(playerID: player.id)
    }

    // MARK: Personal

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Personal")

            VStack(spacing: 10) {
                SettingsRow(icon: "globe.americas.fill", title: "Time zone") {
                    Text(timeZoneLabel)
                        .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                SettingsRow(icon: "clock.fill", title: "24 hour format") {
                    Toggle("", isOn: $use24HourFormat)
                        .labelsHidden()
                        .tint(ThemeManager.emeraldGreen)
                        .courtifySelectionFeedback(use24HourFormat)
                }

                SettingsButtonRow(
                    icon: "crown.fill",
                    title: "Premium subscription",
                    value: revenueCat.isProUser ? "Active" : "Activate"
                ) {
                    if !revenueCat.isProUser {
                        showPaywall = true
                    }
                }

                SettingsButtonRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Restore purchase",
                    value: isRestoring ? "…" : "Restore"
                ) {
                    guard !isRestoring else { return }
                    isRestoring = true
                    Task {
                        let restored = await revenueCat.restorePurchases()
                        isRestoring = false
                        restoreMessage = restored
                            ? "Your purchases have been restored."
                            : "No previous purchases found."
                    }
                }
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Appearance")

            VStack(spacing: 10) {
                SettingsPremiumRow(
                    icon: "paintpalette.fill",
                    title: "App theme",
                    value: appearance.theme.displayName,
                    showsPremiumBadge: !isEntitled,
                    swatch: appearance.canvasColor
                ) {
                    if isEntitled {
                        showThemePicker = true
                    } else {
                        showPaywall = true
                    }
                }

                SettingsPremiumRow(
                    icon: "tennisball.fill",
                    title: "Logo ball",
                    value: appearance.logoBall.displayName,
                    showsPremiumBadge: !isEntitled,
                    swatch: appearance.logoBallColor
                ) {
                    if isEntitled {
                        showBallPicker = true
                    } else {
                        showPaywall = true
                    }
                }
            }
        }
    }

    // MARK: Help

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Help and Feedback")

            VStack(spacing: 10) {
                SettingsButtonRow(icon: "envelope.fill", title: "Contact us", value: nil) {
                    // Placeholder support address until a real inbox exists.
                    if let url = URL(string: "mailto:support@courtify.xyz") {
                        UIApplication.shared.open(url)
                    }
                }

                NavigationLink {
                    HowToAddWidgetsView()
                } label: {
                    SettingsRowLabel(icon: "square.grid.2x2.fill", title: "How to add widgets") {
                        chevron
                    }
                }
                .courtifyButton(.card)

                SettingsButtonRow(icon: "star.fill", title: "Rate us", value: nil) {
                    if let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive }) {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            CourtifyLogoMark(size: 56)

            Text("Courtify")
                .font(ThemeManager.roundedFont(.headline, weight: .bold))
                .foregroundStyle(.white)

            Text(appVersion)
                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
    }
}

// MARK: - Building blocks

private enum FavoriteCardMetrics {
    static let height: CGFloat = 176
    static let slamLogoSize: CGFloat = 86
}

/// Circular slam mark for Settings favorite cards.
private struct FavoriteSlamLogoBadge: View {
    let slam: GrandSlam

    var body: some View {
        ZStack {
            Circle()
                .fill(badgeBackground)

            AssetCatalogImage(
                name: slam.logoImageName,
                contentMode: usesFill ? .fill : .fit
            )
            .padding(logoInset)
        }
        .frame(width: FavoriteCardMetrics.slamLogoSize, height: FavoriteCardMetrics.slamLogoSize)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .opacity(0.95)
    }

    /// Fill for all marks so rectangular assets (US Open) become round badges.
    private var usesFill: Bool { true }

    private var logoInset: CGFloat { 0 }

    private var badgeBackground: Color {
        switch slam {
        case .australianOpen: Color(hex: 0x0085CA).opacity(0.35)
        case .frenchOpen: Color(hex: 0xE35205).opacity(0.25)
        case .wimbledon: Color(hex: 0x006633).opacity(0.3)
        case .usOpen: Color(hex: 0x0C2340)
        }
    }
}

private struct FavoriteCard<Artwork: View>: View {
    let title: String
    let subtitle: String?
    let action: () -> Void
    @ViewBuilder var artwork: () -> Artwork
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                CourtifyAmbientGlow(
                    primary: appearance.liftColor,
                    secondary: appearance.accentColor,
                    intensity: 0.55,
                    anchor: .topTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .opacity(0.7)
            }

            artwork()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 10)
                .padding(.bottom, 48)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 40)

                if let subtitle {
                    Text(subtitle)
                        .font(ThemeManager.roundedFont(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.trailing, 48)
                }

                Spacer(minLength: 0)

                Button(action: action) {
                    Text("Change")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ThemeManager.opticYellow)
                        .clipShape(Capsule())
                }
                .courtifyButton(.ghost)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: FavoriteCardMetrics.height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SettingsRowLabel<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 24)

            Text(title)
                .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .courtifyGlassSurface(cornerRadius: 16)
        .contentShape(Rectangle())
    }
}

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        SettingsRowLabel(icon: icon, title: title, trailing: trailing)
    }
}

private struct SettingsButtonRow: View {
    let icon: String
    let title: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(icon: icon, title: title) {
                HStack(spacing: 8) {
                    if let value {
                        Text(value)
                            .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .courtifyButton(.card)
    }
}

private struct SettingsPremiumRow: View {
    let icon: String
    let title: String
    let value: String
    let showsPremiumBadge: Bool
    var swatch: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24)

                Text(title)
                    .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                    .foregroundStyle(.white)

                if showsPremiumBadge {
                    Text("Premium")
                        .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                if let swatch {
                    Circle()
                        .fill(swatch)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        }
                }
                Text(value)
                    .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .courtifyGlassSurface(cornerRadius: 16)
            .contentShape(Rectangle())
        }
        .courtifyButton(.card)
    }
}

// MARK: - Appearance pickers

private struct AppThemePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        PickerSheetShell(title: "App theme") {
            ForEach(AppThemePreset.allCases) { preset in
                Button {
                    CourtifyMotion.animateSelection {
                        appearance.setTheme(preset)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(preset.color)
                            .frame(width: 44, height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            }

                        Text(preset.displayName)
                            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer(minLength: 0)

                        if appearance.theme == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ThemeManager.opticYellow)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .courtifyGlassSurface(cornerRadius: 16)
                }
                .courtifyButton(.card)
            }
        }
    }
}

private struct LogoBallPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        PickerSheetShell(title: "Logo ball") {
            ForEach(LogoBallPreset.allCases) { preset in
                Button {
                    CourtifyMotion.animateSelection {
                        appearance.setLogoBall(preset)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        CourtifyLogoMark(size: 44, preset: preset)

                        Text(preset.displayName)
                            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer(minLength: 0)

                        if appearance.logoBall == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ThemeManager.opticYellow)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .courtifyGlassSurface(cornerRadius: 16)
                }
                .courtifyButton(.card)
            }
        }
    }
}

// MARK: - Pickers

private struct FavoriteSlamPickerSheet: View {
    @Binding var selectedRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PickerSheetShell(title: "Favorite Grand Slam") {
            ForEach(GrandSlam.allCases) { slam in
                Button {
                    CourtifyMotion.animateSelection {
                        selectedRaw = slam.rawValue
                    }
                    WidgetTimelineRefresher.reloadAll()
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        AssetCatalogImage(name: slam.logoImageName, contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(slam.rawValue)
                                .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(slam.location) · \(slam.surface)")
                                .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                                .foregroundStyle(ThemeManager.courtGreen)
                        }

                        Spacer()

                        if slam.rawValue == selectedRaw {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ThemeManager.opticYellow)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .courtifyButton(.card)

                CourtifyTileDivider()
            }
        }
    }
}

private struct PickerSheetShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.top, 8)
            }
            .background(ThemeManager.oledBlack.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                        .tint(ThemeManager.opticYellow)
                        .courtifyButton(.ghost)
                }
            }
            .toolbarBackground(ThemeManager.oledBlack, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Widgets how-to

private struct HowToAddWidgetsView: View {
    private let steps: [(icon: String, text: String)] = [
        ("hand.tap.fill", "Touch and hold an empty area on your Home Screen until the apps jiggle."),
        ("plus.circle.fill", "Tap the + button in the top-left corner."),
        ("magnifyingglass", "Search for \"Courtify\" in the widget gallery."),
        ("square.grid.2x2.fill", "Pick a size, then tap Add Widget."),
        ("slider.horizontal.3", "Touch and hold the widget to customize your player, tour, or tournament."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ThemeManager.opticYellow)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Step \(index + 1)")
                                .font(ThemeManager.roundedFont(.caption, weight: .bold))
                                .foregroundStyle(.white.opacity(0.45))
                            Text(step.text)
                                .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .courtifyGlassSurface(cornerRadius: 16)
                }
            }
            .padding(20)
        }
        .background(ThemeManager.oledBlack.ignoresSafeArea())
        .navigationTitle("How to add widgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ThemeManager.oledBlack, for: .navigationBar)
    }
}

#Preview {
    SettingsView()
}
