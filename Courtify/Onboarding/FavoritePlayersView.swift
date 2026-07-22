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

    /// Custom picks from the search sheet get their own poster cards (selected +
    /// starred like any featured player) — the More card is purely an "add" affordance.
    private var customSelectedPlayers: [TennisPlayer] {
        selectedPlayerIDs
            .filter { $0.hasPrefix("custom:") }
            .compactMap { id -> TennisPlayer? in
                guard let base = TennisPlayer.player(for: id) else { return nil }
                let rank = PlayerRankCache.rank(for: id) ?? 0
                return TennisPlayer(
                    id: base.id,
                    name: base.name,
                    tour: base.tour,
                    imageName: nil,
                    ranking: rank
                )
            }
            .sorted { $0.name < $1.name }
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

                    ForEach(customSelectedPlayers) { player in
                        PlayerPosterCard(
                            player: player,
                            isSelected: true,
                            isPrimary: favoritePlayerID == player.id
                        ) {
                            togglePlayer(player)
                        }
                        .id("\(player.id)-\(photoRefreshToken)")
                    }

                    MorePlayerPosterCard(
                        isSelected: false,
                        isPrimary: false
                    ) {
                        showCustomPlayerSheet = true
                    }
                }
                .padding(.vertical, 12)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 24, for: .scrollContent)
            // Cards snap to alignment so a poster never rests half-cropped
            // with its name clipped at the screen edge.
            .scrollTargetBehavior(.viewAligned)
            // Lock row height so posters stay true 3:4 (ScrollView otherwise proposes full flex height).
            .frame(height: OnboardingPosterMetrics.height + 28)

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

private enum OnboardingPosterMetrics {
    static let width: CGFloat = 148
    static let cornerRadius: CGFloat = 18
    static let aspect: CGFloat = 3.0 / 4.0
    static var height: CGFloat { width / aspect }
}

private struct MorePlayerPosterCard: View {
    let isSelected: Bool
    let isPrimary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
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
            .frame(width: OnboardingPosterMetrics.width, height: OnboardingPosterMetrics.height)
            .courtifyGlassSurface(cornerRadius: OnboardingPosterMetrics.cornerRadius)
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
                PlayerTorsoPhotoView(
                    player: player,
                    contentMode: .fill,
                    fadePortion: 0.40,
                    circularHeadshotSize: 104,
                    // Rare no-cutout fallback: center the circle so it reads as a
                    // deliberate portrait, not artwork sunk to the card's floor.
                    circularHeadshotAlignment: .center
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .clipped()
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

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
            .frame(width: OnboardingPosterMetrics.width, height: OnboardingPosterMetrics.height)
            .courtifyGlassSurface(cornerRadius: OnboardingPosterMetrics.cornerRadius)
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
                    .courtifyGlassSurface(cornerRadius: 16)

                if !suggestions.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(suggestions) { entry in
                            let player = FavoritePlayerCatalog.player(from: entry)
                            Button {
                                Task { await select(player) }
                            } label: {
                                HStack(spacing: 12) {
                                    TennisPlayerPhotoView(
                                        player: player,
                                        style: .headshot,
                                        size: 40
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                        Text(entry.tour.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .kerning(1.2)
                                            .foregroundStyle(ThemeManager.courtGreen)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .courtifyGlassSurface(cornerRadius: 16)
                                .courtifySelectableCard(isSelected: false, cornerRadius: 16, scale: 1.02)
                            }
                            .courtifyButton(.card)
                            .disabled(isSaving)
                        }
                    }
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    Button {
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
                                        name: trimmed,
                                        tour: resolvedManualTour
                                    )
                                ),
                                style: .headshot,
                                size: 40
                            )

                            Text("Add \"\(trimmed)\"")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(ThemeManager.opticYellow)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .courtifyGlassSurface(cornerRadius: 16)
                    }
                    .courtifyButton(.card)
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
