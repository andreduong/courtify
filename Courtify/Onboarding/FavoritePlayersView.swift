import SwiftUI

struct FavoritePlayersView: View {
    let tourPreference: TourPreference
    @Binding var favoritePlayerID: String
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @State private var selectedPlayerIDs: Set<String> = []
    @State private var showCustomPlayerSheet = false
    @State private var photoRefreshToken = 0

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
                HStack(spacing: 14) {
                    ForEach(featuredPlayers) { player in
                        PlayerPosterCard(
                            player: player,
                            isSelected: selectedPlayerIDs.contains(player.id),
                            isPrimary: favoritePlayerID == player.id
                        ) {
                            togglePlayer(player)
                        }
                        .id("\(player.id)-\(photoRefreshToken)")
                    }

                    MorePlayerPosterCard(
                        isSelected: isCustomSelectionActive,
                        isPrimary: isCustomSelectionActive && favoritePlayerID.hasPrefix("custom:")
                    ) {
                        showCustomPlayerSheet = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
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

            if selectedPlayerIDs.isEmpty {
                Button(action: onContinue) {
                    Text("Skip for now")
                        .courtifySecondaryButtonLabel()
                }
                .courtifyButton(.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else {
                Button {
                    // Ensure #1 is set if the user selected stars but never triggered primary assignment.
                    if favoritePlayerID.isEmpty, let first = selectedPlayerIDs.first {
                        favoritePlayerID = first
                    }
                    onContinue()
                } label: {
                    Text("Continue")
                        .courtifyPrimaryButtonLabel()
                }
                .courtifyButton(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
            if !favoritePlayerID.isEmpty {
                selectedPlayerIDs.insert(favoritePlayerID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppGroupConstants.favoritePlayerDidChange)) { _ in
            photoRefreshToken += 1
        }
        .sheet(isPresented: $showCustomPlayerSheet) {
            CustomPlayerSearchSheet(
                tourPreference: tourPreference,
                onSelect: { player in
                    CourtifyMotion.animateSelection {
                        selectedPlayerIDs.insert(player.id)
                        favoritePlayerID = player.id
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var isCustomSelectionActive: Bool {
        selectedPlayerIDs.contains(where: { $0.hasPrefix("custom:") })
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
                photoRefreshToken += 1
            }
        }
    }
}

private struct OnboardingPosterMetrics {
    static let width: CGFloat = 148
    static let cornerRadius: CGFloat = 18
    static let aspect: CGFloat = 3.0 / 4.0
}

private struct MorePlayerPosterCard: View {
    let isSelected: Bool
    let isPrimary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: OnboardingPosterMetrics.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)

                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeManager.brandYellow)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isPrimary {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(ThemeManager.brandYellow, in: Circle())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("More")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Search name")
                        .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(12)
            }
            .frame(width: OnboardingPosterMetrics.width)
            .aspectRatio(OnboardingPosterMetrics.aspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: OnboardingPosterMetrics.cornerRadius, style: .continuous))
            .courtifySelectableCard(
                isSelected: isSelected,
                cornerRadius: OnboardingPosterMetrics.cornerRadius
            )
        }
        .courtifyButton(.card)
    }
}

private struct PlayerPosterCard: View {
    let player: TennisPlayer
    let isSelected: Bool
    let isPrimary: Bool
    let onTap: () -> Void

    private var lastName: String {
        player.name.components(separatedBy: " ").last ?? player.name
    }

    private var rankLabel: String {
        if player.ranking > 0 {
            return "#\(player.ranking) \(player.tour.rawValue)"
        }
        return player.tour.rawValue
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: OnboardingPosterMetrics.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)

                PlayerTorsoPhotoView(
                    player: player,
                    contentMode: .fit,
                    fadePortion: 0.40
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 4)
                .scaleEffect(1.10, anchor: .bottom)

                if isPrimary {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(ThemeManager.brandYellow, in: Circle())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(lastName)
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(rankLabel)
                        .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                        .foregroundStyle(ThemeManager.brandYellow.opacity(0.9))
                }
                .padding(12)
            }
            .frame(width: OnboardingPosterMetrics.width)
            .aspectRatio(OnboardingPosterMetrics.aspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: OnboardingPosterMetrics.cornerRadius, style: .continuous))
            .courtifySelectableCard(
                isSelected: isSelected,
                cornerRadius: OnboardingPosterMetrics.cornerRadius
            )
        }
        .courtifyButton(.card)
    }
}

private struct CustomPlayerSearchSheet: View {
    let tourPreference: TourPreference
    let onSelect: (TennisPlayer) -> Void

    @ObservedObject private var dataStore = WidgetDataStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var manualTour: TourPreference = .atp
    @State private var isSaving = false
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
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
                    }

                if !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { entry in
                            Button {
                                Task { await select(FavoritePlayerCatalog.player(from: entry)) }
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
                            .disabled(isSaving)

                            if entry.id != suggestions.last?.id {
                                Divider().overlay(Color.white.opacity(0.1))
                            }
                        }
                    }
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await select(
                                FavoritePlayerCatalog.player(
                                    from: PlayerSearchCatalog.Entry(name: trimmed, tour: resolvedManualTour)
                                )
                            )
                        }
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
                    .disabled(isSaving)
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
                        .disabled(isSaving)
                        .courtifyButton(.ghost)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView()
                            .tint(ThemeManager.opticYellow)
                    }
                }
            }
            .onAppear { isFieldFocused = true }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isSaving)
    }

    @MainActor
    private func select(_ player: TennisPlayer) async {
        guard !isSaving else { return }
        isSaving = true
        dataStore.loadCachedPayload()
        await FavoritePlayerEnricher.enrich(
            player,
            payload: dataStore.payload,
            clearExisting: true
        )
        onSelect(player)
        isSaving = false
        dismiss()
    }
}

#Preview {
    FavoritePlayersView(tourPreference: .both, favoritePlayerID: .constant(""), onContinue: {})
        .courtifyBackground()
}
