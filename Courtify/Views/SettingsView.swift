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

    @State private var showPlayerPicker = false
    @State private var showSlamPicker = false
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private var favoritePlayer: TennisPlayer? {
        TennisPlayer.player(for: favoritePlayerID)
    }

    private var favoriteSlam: GrandSlam? {
        GrandSlam(rawValue: favoriteGrandSlamRaw)
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
                    helpSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
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
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .courtifyButton(.icon)
                }
            }
            .toolbarBackground(ThemeManager.midnightGreen, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPlayerPicker) {
            FavoritePlayerPickerSheet(selectedID: $favoritePlayerID)
        }
        .sheet(isPresented: $showSlamPicker) {
            FavoriteSlamPickerSheet(selectedRaw: $favoriteGrandSlamRaw)
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
                    subtitle: "Fav player",
                    action: { showPlayerPicker = true }
                ) {
                    if let player = favoritePlayer {
                        CachedBundledImage(name: player.heroImageName, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.top, 26)
                    }
                }

                FavoriteCard(
                    title: favoriteSlam?.rawValue.uppercased() ?? "PICK A SLAM",
                    subtitle: "Fav Grand Slam",
                    action: { showSlamPicker = true }
                ) {
                    if let slam = favoriteSlam {
                        CachedBundledImage(name: slam.logoImageName, contentMode: .fit)
                            .frame(width: 84, height: 84)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding([.bottom, .trailing], 10)
                            .opacity(0.85)
                    }
                }
            }
        }
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
            CachedBundledImage(name: "courtify-logo", contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

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

private struct FavoriteCard<Artwork: View>: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    @ViewBuilder var artwork: () -> Artwork

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [ThemeManager.emeraldGreen.opacity(0.85), ThemeManager.midnightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            artwork()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer(minLength: 0)

                Button(action: action) {
                    Text("Change")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                        .foregroundStyle(ThemeManager.midnightGreen)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .courtifyButton(.ghost)
            }
            .padding(14)
        }
        .frame(height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

// MARK: - Pickers

private struct FavoritePlayerPickerSheet: View {
    @Binding var selectedID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PickerSheetShell(title: "Favorite player") {
            ForEach(TennisPlayer.topPlayers) { player in
                Button {
                    CourtifyMotion.animateSelection {
                        selectedID = player.id
                    }
                    AppGroupConstants.updateFavoritePlayer(player.id)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        CachedBundledImage(name: player.resolvedImageName, contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.name)
                                .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(player.tour.rawValue)
                                .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                                .foregroundStyle(ThemeManager.courtGreen)
                        }

                        Spacer()

                        if player.id == selectedID {
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
                        CachedBundledImage(name: slam.logoImageName, contentMode: .fit)
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
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                        .tint(ThemeManager.opticYellow)
                }
            }
            .toolbarBackground(ThemeManager.midnightGreen, for: .navigationBar)
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
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(20)
        }
        .background(ThemeManager.midnightGreen.ignoresSafeArea())
        .navigationTitle("How to add widgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ThemeManager.midnightGreen, for: .navigationBar)
    }
}

#Preview {
    SettingsView()
}
