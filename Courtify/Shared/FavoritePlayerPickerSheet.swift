import SwiftUI

struct FavoritePlayerPickerSheet: View {
    @Binding var favoritePlayerID: String
    @ObservedObject private var dataStore = WidgetDataStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var isSaving = false
    @State private var photoRefreshToken = 0
    @FocusState private var isSearchFocused: Bool

    private var rankedPlayers: [TennisPlayer] {
        FavoritePlayerCatalog.pickerPlayers(payload: dataStore.payload)
    }

    private var isRefreshingRankings: Bool {
        dataStore.isLoading && dataStore.payload == nil
    }

    private var searchSuggestions: [TennisPlayer] {
        FavoritePlayerCatalog.searchPlayers(query: searchQuery)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    searchSection

                    if isRefreshingRankings {
                        rankingsLoadingRow
                    }

                    if !atpPlayers.isEmpty {
                        sectionHeader("ATP")
                        playerRows(atpPlayers)
                    }
                    if !wtaPlayers.isEmpty {
                        sectionHeader("WTA")
                        playerRows(wtaPlayers)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .courtifyBackground()
            .navigationTitle("Favorite player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ThemeManager.opticYellow)
                        .disabled(isSaving)
                        .courtifyButton(.ghost)
                }
            }
            .courtifyThemedNavigationBar()
            .task {
                await dataStore.ensureRankingsLoaded()
                await FavoritePlayerEnricher.prefetchPickerHeadshots(payload: dataStore.payload)
                photoRefreshToken += 1
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
        }
        .preferredColorScheme(.dark)
    }

    private var atpPlayers: [TennisPlayer] {
        rankedPlayers.filter { $0.tour == .atp }
    }

    private var wtaPlayers: [TennisPlayer] {
        rankedPlayers.filter { $0.tour == .wta }
    }

    private var rankingsLoadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(ThemeManager.opticYellow)
            Text("Loading latest rankings…")
                .font(ThemeManager.roundedFont(.footnote, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ThemeManager.roundedFont(.caption, weight: .bold))
            .foregroundStyle(ThemeManager.opticYellow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    private func playerRows(_ players: [TennisPlayer]) -> some View {
        VStack(spacing: 10) {
            ForEach(players) { player in
                playerRow(player)
            }
        }
        .padding(.horizontal, 20)
    }

    private func playerRow(_ player: TennisPlayer) -> some View {
        let isSelected = favoritePlayerID == player.id
        return Button {
            Task { await select(player) }
        } label: {
            HStack(spacing: 14) {
                TennisPlayerPhotoView(player: player, style: .headshot, size: 44)
                    .id("\(player.id)-\(photoRefreshToken)")

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(rankSubtitle(for: player))
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
            .courtifySelectableCard(isSelected: isSelected, cornerRadius: 16, scale: 1.02)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .courtifyButton(.card)
        .disabled(isSaving)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Search")
            Text("Find a player outside the top 10")
                .font(ThemeManager.roundedFont(.footnote))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 20)

            TextField("Player name", text: $searchQuery)
                .font(ThemeManager.roundedFont(.body, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .courtifyGlassSurface(cornerRadius: 16)
                .padding(.horizontal, 20)

            if !searchSuggestions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(searchSuggestions) { player in
                        let isSelected = favoritePlayerID == player.id
                        Button {
                            Task { await select(player) }
                        } label: {
                            HStack(spacing: 12) {
                                TennisPlayerPhotoView(player: player, style: .headshot, size: 40)
                                    .id("\(player.id)-\(photoRefreshToken)")

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    Text(rankSubtitle(for: player))
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
                            .courtifySelectableCard(isSelected: isSelected, cornerRadius: 16, scale: 1.02)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .courtifyButton(.card)
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 20)
            } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                Button {
                    Task {
                        await select(FavoritePlayerCatalog.playerForManualName(trimmed, payload: dataStore.payload))
                    }
                } label: {
                    HStack(spacing: 12) {
                        TennisPlayerPhotoView(
                            player: FavoritePlayerCatalog.playerForManualName(trimmed, payload: dataStore.payload),
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
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
    }

    private func rankSubtitle(for player: TennisPlayer) -> String {
        if player.ranking > 0 {
            return "\(player.tour.rawValue) · No. \(player.ranking)"
        }
        return player.tour.rawValue
    }

    @MainActor
    private func select(_ player: TennisPlayer) async {
        guard !isSaving else { return }
        isSaving = true
        dataStore.loadCachedPayload()

        let previousID = favoritePlayerID
        // Persist immediately so Home/Settings update without waiting on network.
        AppGroupConstants.updateFavoritePlayer(player.id)
        favoritePlayerID = player.id

        let payload = dataStore.payload
        isSaving = false
        dismiss()

        // Background enrich — progressive photo load via favoritePlayerDidChange.
        Task { @MainActor in
            await FavoritePlayerEnricher.enrich(
                player,
                payload: payload,
                clearExisting: previousID != player.id
            )
        }
    }
}
