import WidgetKit
import SwiftUI

// MARK: - Entry

struct PlayerTrackerEntry: TimelineEntry {
    let date: Date
    let playerName: String
    let rank: Int?
    let backgroundImagePath: String?
    let liveMatch: WidgetLiveMatch?
    let nextMatchStart: Date?
    let isPlaceholder: Bool
}

// MARK: - Provider

struct PlayerTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlayerTrackerEntry {
        PlayerTrackerEntry(
            date: .now,
            playerName: "Jannik Sinner",
            rank: 2,
            backgroundImagePath: nil,
            liveMatch: nil,
            nextMatchStart: Date().addingTimeInterval(3600),
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PlayerTrackerEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let entry = await buildEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlayerTrackerEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func buildEntry() async -> PlayerTrackerEntry {
        do {
            let payload = try await WidgetAPIService.fetchWidgetData()
            let favoritePlayer = FavoritePlayerResolver.favoritePlayer(from: payload)
            let ranking = FavoritePlayerResolver.ranking(for: payload)
            let liveMatch = FavoritePlayerResolver.liveMatch(for: payload)
            let upcoming = FavoritePlayerResolver.nextUpcomingMatch(for: payload)

            var imagePath: String?
            if let player = favoritePlayer ?? ranking?.player, let id = player.id, let url = player.imageURL {
                imagePath = await WidgetImageCache.cachedImagePath(forPlayerID: id, remoteURL: url)
            }

            return PlayerTrackerEntry(
                date: .now,
                playerName: favoritePlayer?.name ?? ranking?.player.name ?? "Your Player",
                rank: ranking?.rank,
                backgroundImagePath: imagePath,
                liveMatch: liveMatch,
                nextMatchStart: upcoming?.startTime,
                isPlaceholder: false
            )
        } catch {
            return PlayerTrackerEntry(
                date: .now,
                playerName: FavoritePlayerResolver.favoriteDisplayName() ?? "Courtify",
                rank: nil,
                backgroundImagePath: nil,
                liveMatch: nil,
                nextMatchStart: nil,
                isPlaceholder: false
            )
        }
    }
}

// MARK: - Widget

struct PlayerTrackerWidget: Widget {
    let kind = "PlayerTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlayerTrackerProvider()) { entry in
            PlayerTrackerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.midnightGreen
                }
        }
        .configurationDisplayName("Player Tracker")
        .description("Live rank and match status for your favorite player.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

struct PlayerTrackerWidgetView: View {
    let entry: PlayerTrackerEntry

    var body: some View {
        ZStack {
            backgroundLayer
            LinearGradient(
                colors: [
                    WidgetTheme.midnightGreen.opacity(0.15),
                    WidgetTheme.midnightGreen.opacity(0.55),
                    WidgetTheme.midnightGreen.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                if let rank = entry.rank {
                    Text("ATP #\(rank)")
                        .font(WidgetTheme.roundedFont(size: 22, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)
                }

                Text(entry.playerName.components(separatedBy: " ").last ?? entry.playerName)
                    .font(WidgetTheme.roundedFont(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let live = entry.liveMatch {
                    liveScoreSection(live)
                } else {
                    countdownSection
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let path = entry.backgroundImagePath, let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [WidgetTheme.emeraldGreen, WidgetTheme.midnightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func liveScoreSection(_ match: WidgetLiveMatch) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(WidgetTheme.opticYellow)
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(WidgetTheme.roundedFont(size: 10, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
            }

            playerNameRow(name: match.player1.name, isServing: match.server == 1)
            playerNameRow(name: match.player2.name, isServing: match.server == 2)

            if let setScore = match.score {
                Text(setScore)
                    .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let gameScore = match.gameScore {
                Text(gameScore)
                    .font(WidgetTheme.roundedFont(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private func playerNameRow(name: String, isServing: Bool) -> some View {
        HStack(spacing: 4) {
            if isServing {
                Circle()
                    .fill(WidgetTheme.opticYellow)
                    .frame(width: 7, height: 7)
            }
            Text(name.components(separatedBy: " ").last ?? name)
                .font(WidgetTheme.roundedFont(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Next match")
                .font(WidgetTheme.roundedFont(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            if let start = entry.nextMatchStart {
                Text(start, style: .timer)
                    .font(WidgetTheme.roundedFont(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } else {
                Text("-")
                    .font(WidgetTheme.roundedFont(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

#Preview(as: .systemSmall) {
    PlayerTrackerWidget()
} timeline: {
    PlayerTrackerEntry(
        date: .now,
        playerName: "Carlos Alcaraz",
        rank: 3,
        backgroundImagePath: nil,
        liveMatch: WidgetLiveMatch(
            id: 1,
            tour: "ATP",
            tournament: "Wimbledon",
            court: "Centre Court",
            status: "LIVE",
            score: "6-4 3-2",
            gameScore: "40-30",
            server: 1,
            player1: WidgetPlayer(id: 1, name: "Carlos Alcaraz", country: "ESP", imageUrl: nil),
            player2: WidgetPlayer(id: 2, name: "Novak Djokovic", country: "SRB", imageUrl: nil)
        ),
        nextMatchStart: nil,
        isPlaceholder: true
    )
}
