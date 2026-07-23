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

    @AppStorage(AppGroupConstants.Keys.referralBypassActive, store: AppGroupConstants.appGroupStorage)
    private var referralBypassActive = false

    @StateObject private var revenueCat = RevenueCatManager.shared
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @ObservedObject private var appearance = AppAppearanceStore.shared

    @State private var showPlayerPicker = false
    @State private var showSlamPicker = false
    @State private var showPaywall = false
    @State private var showThemePicker = false
    @State private var showBallPicker = false
    @State private var showReferralSheet = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private var favoritePlayer: TennisPlayer? {
        FavoritePlayerCatalog.resolvedPlayer(id: favoritePlayerID, payload: dataStore.payload)
    }

    private var favoriteSlam: GrandSlam? {
        GrandSlam(rawValue: favoriteGrandSlamRaw)
    }

    private var isEntitled: Bool {
        revenueCat.isProUser || referralBypassActive
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
            .background {
                ZStack {
                    ThemeManager.oledBlack
                    CourtifyListAmbientBloom()
                }
                .ignoresSafeArea()
            }
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
                                    .stroke(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
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
        .sheet(isPresented: $showReferralSheet) {
            SettingsReferralCodeSheet()
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
                        PlayerTorsoPhotoView(
                            player: player,
                            contentMode: .fit,
                            fadesIntoBackground: player.imageName != nil,
                            circularHeadshotSize: 72
                        )
                        .frame(width: 92, height: 108)
                        .opacity(0.9)
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
        guard !PlayerPhotoStore.hasCachedPhotos(playerID: player.id) else { return false }
        // Only surface quota — inactive/unranked fails silently with silhouette.
        return FavoritePlayerEnricher.mediaFailureReason == .quota
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
                    value: isEntitled ? "Active" : "Activate"
                ) {
                    if !isEntitled {
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

                SettingsButtonRow(
                    icon: "ticket.fill",
                    title: "Enter referral code",
                    value: nil
                ) {
                    showReferralSheet = true
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
                    swatch: appearance.theme.pickerSwatchAccent
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
        SlamLogoBadge(slam: slam, size: FavoriteCardMetrics.slamLogoSize)
            .opacity(0.95)
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
            // Transparent bloom only — CourtifyAmbientGlow paints OLED black and kills glass.
            RadialGradient(
                colors: [
                    appearance.accentColor.opacity(0.18),
                    appearance.liftColor.opacity(0.10),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 160
            )
            .blur(radius: 40)
            .allowsHitTesting(false)

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
                        .background(ThemeManager.brandYellow)
                        .clipShape(Capsule())
                        .shadow(color: ThemeManager.brandYellow.opacity(0.4), radius: 12, y: 4)
                }
                .courtifyButton(.ghost)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: FavoriteCardMetrics.height)
        .courtifyGlassSurface(cornerRadius: 20)
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

/// Black tile + accent dot — mirrors **Logo ball** picker chrome.
private struct AppThemePickerSwatch: View {
    let preset: AppThemePreset

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(ThemeManager.oledBlack)
            .frame(width: 44, height: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(preset.pickerSwatchAccent.opacity(0.9), lineWidth: 2)
            }
            .overlay {
                Circle()
                    .fill(preset.pickerSwatchAccent)
                    .frame(width: 16, height: 16)
                    .shadow(color: preset.pickerSwatchAccent.opacity(0.45), radius: 5)
            }
    }
}

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
                        AppThemePickerSwatch(preset: preset)

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
                        SlamLogoBadge(slam: slam, size: 44)

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

// MARK: - Referral code (Settings)

private struct SettingsReferralCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared

    @AppStorage(AppGroupConstants.Keys.referralBypassActive, store: AppGroupConstants.appGroupStorage)
    private var referralBypassActive = false

    @State private var referralCode = ""
    @State private var feedback: Feedback = .none
    @State private var shakeInvalid = false
    @State private var successPulse = false
    @State private var errorPulse = 0
    @FocusState private var isFieldFocused: Bool

    private enum Feedback: Equatable {
        case none
        case invalid
        case alreadyPremium
        case unlocked
    }

    private var isEntitled: Bool {
        revenueCat.isProUser || referralBypassActive
    }

    private var canSubmit: Bool {
        !referralCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && feedback != .unlocked
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter referral code")
                            .font(ThemeManager.roundedFont(.title2, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Have a Courtify invite? Unlock Premium instantly.")
                            .font(ThemeManager.roundedFont(.subheadline))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    TextField("Referral code", text: $referralCode)
                        .font(ThemeManager.roundedFont(.body, weight: .medium))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(.none)
                        .focused($isFieldFocused)
                        .submitLabel(.go)
                        .onSubmit(submitCode)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(fieldBorderColor, lineWidth: fieldBorderWidth)
                        }
                        .offset(x: shakeInvalid ? -6 : 0)
                        .animation(
                            shakeInvalid
                                ? .default.repeatCount(3, autoreverses: true).speed(4)
                                : CourtifyMotion.selection,
                            value: shakeInvalid
                        )
                        .disabled(feedback == .unlocked)
                        .onChange(of: referralCode) { _, _ in
                            guard feedback == .invalid || feedback == .alreadyPremium else { return }
                            CourtifyMotion.animateSelection {
                                feedback = .none
                                shakeInvalid = false
                            }
                        }

                    feedbackLabel

                    Button(action: submitCode) {
                        Text(feedback == .unlocked ? "UNLOCKED" : "SUBMIT")
                            .courtifyPrimaryButtonLabel(cornerRadius: 16)
                    }
                    .courtifyButton(.primary, enabled: canSubmit)
                    .sensoryFeedback(.success, trigger: successPulse)
                    .sensoryFeedback(.error, trigger: errorPulse)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                ZStack {
                    ThemeManager.oledBlack
                    CourtifyListAmbientBloom()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Referral code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isFieldFocused = false
                        dismiss()
                    }
                    .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                    .tint(ThemeManager.opticYellow)
                    .courtifyButton(.ghost)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Go") {
                        submitCode()
                    }
                    .font(ThemeManager.roundedFont(.body, weight: .semibold))
                    .foregroundStyle(ThemeManager.opticYellow)
                    .disabled(!canSubmit)
                }
            }
            .toolbarBackground(ThemeManager.oledBlack, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .animation(CourtifyMotion.selection, value: feedback)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        switch feedback {
        case .none:
            EmptyView()
        case .invalid:
            Text("That code isn't recognized. Try again.")
                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                .foregroundStyle(.red.opacity(0.85))
                .transition(CourtifyMotion.crossfade)
        case .alreadyPremium:
            Text("You're already a Premium user")
                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                .foregroundStyle(.red.opacity(0.85))
                .transition(CourtifyMotion.crossfade)
        case .unlocked:
            Text("Premium unlocked — enjoy Courtify.")
                .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                .foregroundStyle(ThemeManager.opticYellow)
                .transition(CourtifyMotion.crossfade)
        }
    }

    private var fieldBorderColor: Color {
        switch feedback {
        case .invalid, .alreadyPremium:
            return Color.red.opacity(0.7)
        case .unlocked:
            return ThemeManager.opticYellow.opacity(0.7)
        case .none:
            return ThemeManager.glassEdge
        }
    }

    private var fieldBorderWidth: CGFloat {
        feedback == .none ? ThemeManager.glassEdgeWidth : 1.5
    }

    private func submitCode() {
        let trimmed = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, feedback != .unlocked else { return }

        isFieldFocused = false

        guard ReferralAccess.isValid(trimmed) else {
            errorPulse += 1
            CourtifyMotion.animateSelection {
                feedback = .invalid
                shakeInvalid = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                shakeInvalid = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                guard feedback == .invalid else { return }
                CourtifyMotion.animateSelection {
                    feedback = .none
                }
            }
            return
        }

        if isEntitled {
            errorPulse += 1
            CourtifyMotion.animateSelection {
                feedback = .alreadyPremium
            }
            return
        }

        AppGroupConstants.activateReferralBypass()
        referralBypassActive = true
        OfferNotificationManager.cancelSubscriptionRemindersIfEntitled()
        successPulse.toggle()
        CourtifyMotion.animateSelection {
            feedback = .unlocked
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            dismiss()
        }
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
