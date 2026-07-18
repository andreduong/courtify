import SwiftUI

struct FavoritePlayersView: View {
    let tourPreference: TourPreference
    @Binding var favoritePlayerID: String
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @State private var selectedPlayerIDs: Set<String> = []
    @State private var showCustomPlayerSheet = false

    let onContinue: () -> Void

    /// Real top-10 rankings fetched once on first launch; bundled players are
    /// only a fallback when that fetch failed (offline first open).
    private var featuredPlayers: [TennisPlayer] {
        let real = realRankedPlayers
        return real.isEmpty ? TennisPlayer.topFive(for: tourPreference) : real
    }

    private var realRankedPlayers: [TennisPlayer] {
        guard let payload = dataStore.payload else { return [] }
        switch tourPreference {
        case .atp:
            return FavoritePlayerCatalog.rankedPlayers(from: payload.rankings.atp, tour: .atp, limit: 10)
        case .wta:
            return FavoritePlayerCatalog.rankedPlayers(from: payload.rankings.wta, tour: .wta, limit: 10)
        case .both:
            return FavoritePlayerCatalog.rankedPlayers(from: payload.rankings.atp, tour: .atp, limit: 5)
                + FavoritePlayerCatalog.rankedPlayers(from: payload.rankings.wta, tour: .wta, limit: 5)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Favorite your stars")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("Tap to follow top-ranked players. Your #1 pick personalizes your experience.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(featuredPlayers) { player in
                        PlayerAvatarCard(
                            player: player,
                            isSelected: selectedPlayerIDs.contains(player.id),
                            isPrimary: favoritePlayerID == player.id
                        ) {
                            togglePlayer(player)
                        }
                    }

                    MorePlayerCard(
                        isSelected: isCustomSelectionActive,
                        isPrimary: isCustomSelectionActive && favoritePlayerID.hasPrefix("custom:")
                    ) {
                        showCustomPlayerSheet = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            if !favoritePlayerID.isEmpty,
               let primaryName = TennisPlayer.displayName(for: favoritePlayerID) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(ThemeManager.opticYellow)
                    Text("\(primaryName) is your #1")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                // Ensure #1 is set if the user selected stars but never triggered primary assignment.
                if favoritePlayerID.isEmpty, let first = selectedPlayerIDs.first {
                    favoritePlayerID = first
                }
                onContinue()
            } label: {
                Text(selectedPlayerIDs.isEmpty ? "Skip for now" : "Continue")
                    .courtifyPrimaryButtonLabel(fillOpacity: selectedPlayerIDs.isEmpty ? 0.5 : 1)
            }
            .courtifyButton(.primary, enabled: true)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
            if !favoritePlayerID.isEmpty {
                selectedPlayerIDs.insert(favoritePlayerID)
            }
        }
        .sheet(isPresented: $showCustomPlayerSheet) {
            CustomPlayerSearchSheet(
                tourPreference: tourPreference,
                onSelect: { entry in
                    let player = customPlayer(from: entry)
                    Task { await selectCustomPlayer(player) }
                    showCustomPlayerSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var isCustomSelectionActive: Bool {
        selectedPlayerIDs.contains(where: { $0.hasPrefix("custom:") })
    }

    private func customPlayer(from entry: PlayerSearchCatalog.Entry) -> TennisPlayer {
        FavoritePlayerCatalog.player(from: entry)
    }

    @MainActor
    private func selectCustomPlayer(_ player: TennisPlayer) async {
        dataStore.loadCachedPayload()
        await FavoritePlayerEnricher.enrich(
            player,
            payload: dataStore.payload,
            clearExisting: true
        )

        CourtifyMotion.animateSelection {
            selectedPlayerIDs.insert(player.id)
            favoritePlayerID = player.id
        }
    }

    private func togglePlayer(_ player: TennisPlayer) {
        let isAdding = !selectedPlayerIDs.contains(player.id)
        var becamePrimary = false

        CourtifyMotion.animateSelection {
            if selectedPlayerIDs.contains(player.id) {
                selectedPlayerIDs.remove(player.id)
                if favoritePlayerID == player.id {
                    favoritePlayerID = selectedPlayerIDs.first ?? ""
                }
            } else {
                selectedPlayerIDs.insert(player.id)
                if favoritePlayerID.isEmpty {
                    favoritePlayerID = player.id
                    becamePrimary = true
                }
            }
        }

        if isAdding, (becamePrimary || favoritePlayerID == player.id), player.imageName == nil {
            Task {
                dataStore.loadCachedPayload()
                await FavoritePlayerEnricher.enrich(
                    player,
                    payload: dataStore.payload,
                    clearExisting: false
                )
            }
        }
    }
}

private struct MorePlayerCard: View {
    let isSelected: Bool
    let isPrimary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ThemeManager.emeraldGreen.opacity(0.5), ThemeManager.midnightGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(ThemeManager.opticYellow)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? ThemeManager.opticYellow : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 3 : 1
                                )
                        }

                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(ThemeManager.midnightGreen)
                            .padding(5)
                            .background(ThemeManager.opticYellow)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(spacing: 4) {
                    Text("More")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Search name")
                        .font(ThemeManager.roundedFont(.caption2))
                        .foregroundStyle(ThemeManager.emeraldGreen)
                }
            }
            .frame(width: 100)
            .glassCard(cornerRadius: 16, padding: 12)
            .courtifySelection(isSelected, scale: 1.04)
        }
        .courtifyButton(.card)
    }
}

private struct PlayerAvatarCard: View {
    let player: TennisPlayer
    let isSelected: Bool
    let isPrimary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    TennisPlayerPhotoView(player: player, style: .headshot, size: 88)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? ThemeManager.opticYellow : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 3 : 1
                                )
                        }

                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(ThemeManager.midnightGreen)
                            .padding(5)
                            .background(ThemeManager.opticYellow)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(spacing: 4) {
                    Text(player.name.components(separatedBy: " ").last ?? player.name)
                        .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if player.ranking > 0 {
                        Text("#\(player.ranking) \(player.tour.rawValue)")
                            .font(ThemeManager.roundedFont(.caption2))
                            .foregroundStyle(ThemeManager.emeraldGreen)
                    } else {
                        Text(player.tour.rawValue)
                            .font(ThemeManager.roundedFont(.caption2))
                            .foregroundStyle(ThemeManager.emeraldGreen)
                    }
                }
            }
            .frame(width: 100)
            .glassCard(cornerRadius: 16, padding: 12)
            .courtifySelection(isSelected, scale: 1.04)
        }
        .courtifyButton(.card)
    }
}

private struct CustomPlayerSearchSheet: View {
    let tourPreference: TourPreference
    let onSelect: (PlayerSearchCatalog.Entry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var manualTour: TourPreference = .atp
    @FocusState private var isFieldFocused: Bool

    private var suggestions: [PlayerSearchCatalog.Entry] {
        PlayerSearchCatalog.suggestions(query: query, tourPreference: tourPreference)
    }

    private var resolvedManualTour: TourPreference {
        tourPreference == .both ? manualTour : (tourPreference == .wta ? .wta : .atp)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Find a player by name. We'll use a tour placeholder icon - no photo lookup needed.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))

                if tourPreference == .both {
                    Picker("Tour", selection: $manualTour) {
                        Text("ATP").tag(TourPreference.atp)
                        Text("WTA").tag(TourPreference.wta)
                    }
                    .pickerStyle(.segmented)
                }

                TextField("Player name", text: $query)
                    .font(ThemeManager.roundedFont(.body, weight: .medium))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                HStack(spacing: 12) {
                                    TennisPlayerPhotoView(
                                        player: FavoritePlayerCatalog.player(from: entry),
                                        style: .headshot,
                                        size: 36
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(ThemeManager.roundedFont(.body, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(entry.tour.rawValue)
                                            .font(ThemeManager.roundedFont(.caption))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 4)
                            }
                            .courtifyButton(.ghost)

                            if entry.id != suggestions.last?.id {
                                Divider().overlay(Color.white.opacity(0.1))
                            }
                        }
                    }
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSelect(PlayerSearchCatalog.Entry(name: trimmed, tour: resolvedManualTour))
                    } label: {
                        HStack(spacing: 12) {
                            TennisPlayerPhotoView(
                                player: FavoritePlayerCatalog.player(
                                    from: PlayerSearchCatalog.Entry(
                                        name: query.trimmingCharacters(in: .whitespacesAndNewlines),
                                        tour: resolvedManualTour
                                    )
                                ),
                                style: .headshot,
                                size: 36
                            )

                            Text("Add \"\(query.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                                .font(ThemeManager.roundedFont(.body, weight: .semibold))
                                .foregroundStyle(ThemeManager.opticYellow)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .courtifyButton(.ghost)
                }

                Spacer()
            }
            .padding(24)
            .courtifyBackground()
            .navigationTitle("Add a player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ThemeManager.opticYellow)
                        .courtifyButton(.ghost)
                }
            }
            .onAppear { isFieldFocused = true }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    FavoritePlayersView(tourPreference: .both, favoritePlayerID: .constant(""), onContinue: {})
        .courtifyBackground()
}
