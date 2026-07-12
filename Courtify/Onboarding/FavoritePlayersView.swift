import SwiftUI

struct FavoritePlayersView: View {
    let tourPreference: TourPreference
    @Binding var favoritePlayerID: String
    @State private var selectedPlayerIDs: Set<String> = []

    let onContinue: () -> Void

    private var filteredPlayers: [TennisPlayer] {
        switch tourPreference {
        case .atp:
            TennisPlayer.topPlayers.filter { $0.tour == .atp }
        case .wta:
            TennisPlayer.topPlayers.filter { $0.tour == .wta }
        case .both:
            TennisPlayer.topPlayers
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
                    ForEach(filteredPlayers) { player in
                        PlayerAvatarCard(
                            player: player,
                            isSelected: selectedPlayerIDs.contains(player.id),
                            isPrimary: favoritePlayerID == player.id
                        ) {
                            togglePlayer(player)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            if !favoritePlayerID.isEmpty,
               let primary = TennisPlayer.topPlayers.first(where: { $0.id == favoritePlayerID }) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(ThemeManager.opticYellow)
                    Text("\(primary.name) is your #1")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button(action: onContinue) {
                Text(selectedPlayerIDs.isEmpty ? "Skip for now" : "Continue")
                    .courtifyPrimaryButtonLabel(fillOpacity: selectedPlayerIDs.isEmpty ? 0.5 : 1)
            }
            .courtifyButton(.primary, enabled: true)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            if !favoritePlayerID.isEmpty {
                selectedPlayerIDs.insert(favoritePlayerID)
            }
        }
    }

    private func togglePlayer(_ player: TennisPlayer) {
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
                }
            }
        }
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
                    Group {
                        if let url = player.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    placeholder
                                default:
                                    placeholder.overlay { ProgressView().tint(ThemeManager.opticYellow) }
                                }
                            }
                        } else {
                            placeholder
                        }
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
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

                    Text("#\(player.ranking) \(player.tour.rawValue)")
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

    private var placeholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [ThemeManager.emeraldGreen, ThemeManager.midnightGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(player.name.prefix(1))
                    .font(ThemeManager.roundedFont(size: 32, weight: .bold))
                    .foregroundStyle(ThemeManager.opticYellow)
            }
    }
}

#Preview {
    FavoritePlayersView(tourPreference: .both, favoritePlayerID: .constant(""), onContinue: {})
        .courtifyBackground()
}
