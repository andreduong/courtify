import SwiftUI

struct HomeView: View {
    @AppStorage("tourPreference") private var tourPreferenceRaw = TourPreference.both.rawValue
    @AppStorage("favoritePlayerID", store: AppGroupConstants.userDefaults) private var favoritePlayerID = ""
    @AppStorage("favoriteGrandSlam", store: AppGroupConstants.userDefaults) private var favoriteGrandSlam = ""

    @State private var widgetStatusMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeManager.opticYellow)

                Text("Welcome to Courtify")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    if let pref = TourPreference(rawValue: tourPreferenceRaw) {
                        Label("Following \(pref.rawValue)", systemImage: "checkmark.circle.fill")
                    }
                    if let name = TennisPlayer.displayName(for: favoritePlayerID) {
                        Label("Favorite: \(name)", systemImage: "star.fill")
                    }
                    if !favoriteGrandSlam.isEmpty {
                        Label("Grand Slam: \(favoriteGrandSlam)", systemImage: "trophy.fill")
                    }
                }
                .font(ThemeManager.roundedFont(.subheadline))
                .foregroundStyle(.white.opacity(0.7))

                widgetManagementSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .courtifyBackground()
    }

    private var widgetManagementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Widgets")
                .font(ThemeManager.roundedFont(.headline, weight: .bold))
                .foregroundStyle(.white)

            Text("Add Courtify widgets from the iOS home screen widget gallery. Use the controls below to update what they show without calling the live API.")
                .font(ThemeManager.roundedFont(.footnote))
                .foregroundStyle(.white.opacity(0.65))

            #if DEBUG
            Toggle("Use mock widget data", isOn: Binding(
                get: { AppGroupConstants.useMockWidgetData },
                set: { AppGroupConstants.setUseMockWidgetData($0) }
            ))
            .tint(ThemeManager.opticYellow)
            .foregroundStyle(.white)
            #endif

            Menu {
                ForEach(TennisPlayer.topPlayers.filter { $0.tour == .atp }.prefix(5)) { player in
                    Button(player.name) {
                        updateWidgetFavorite(playerID: player.id, grandSlam: favoriteGrandSlam.isEmpty ? "Wimbledon" : favoriteGrandSlam)
                    }
                }
            } label: {
                Label("Update Widget Favorite", systemImage: "person.crop.circle.badge.plus")
                    .courtifyPrimaryButtonLabel(cornerRadius: 12, verticalPadding: 14)
            }
            .courtifyButton(.primary)

            Button {
                seedWidgetFavorites()
            } label: {
                Label("Add Widget Data (Seed Favorites)", systemImage: "plus.rectangle.on.rectangle")
                    .courtifySecondaryButtonLabel()
            }
            .courtifyButton(.secondary)

            Button {
                clearWidgetFavorites()
            } label: {
                Label("Delete Widget Data", systemImage: "trash")
                    .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .courtifyButton(.ghost)

            if !widgetStatusMessage.isEmpty {
                Text(widgetStatusMessage)
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(ThemeManager.opticYellow)
                    .transition(CourtifyMotion.crossfade)
            }
        }
        .animation(CourtifyMotion.selection, value: widgetStatusMessage)
        .glassCard(cornerRadius: 16, padding: 18)
    }

    private func seedWidgetFavorites() {
        AppGroupConstants.commitOnboarding(
            tourPreference: .both,
            favoritePlayerID: "sinner",
            favoriteGrandSlam: "Wimbledon"
        )
        favoritePlayerID = "sinner"
        favoriteGrandSlam = "Wimbledon"
        widgetStatusMessage = "Widget data added for Jannik Sinner · Wimbledon. Add widgets from the home screen gallery."
    }

    private func updateWidgetFavorite(playerID: String, grandSlam: String) {
        favoritePlayerID = playerID
        favoriteGrandSlam = grandSlam
        AppGroupConstants.userDefaults.set(grandSlam, forKey: AppGroupConstants.Keys.favoriteGrandSlam)
        AppGroupConstants.updateFavoritePlayer(playerID)
        let name = TennisPlayer.displayName(for: playerID) ?? playerID
        widgetStatusMessage = "Widgets refreshed for \(name)."
    }

    private func clearWidgetFavorites() {
        AppGroupConstants.clearWidgetFavorites()
        favoritePlayerID = ""
        favoriteGrandSlam = ""
        widgetStatusMessage = "Widget favorites cleared. Remove widgets from the home screen manually if needed."
    }
}

#Preview {
    HomeView()
}
