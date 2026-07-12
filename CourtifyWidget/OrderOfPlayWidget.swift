import WidgetKit
import SwiftUI

// MARK: - Entry

struct OrderOfPlayEntry: TimelineEntry {
    let date: Date
    let centerCourtLive: WidgetLiveMatch?
    let upcoming: [WidgetUpcomingMatch]
    let tournamentName: String?
    let isPlaceholder: Bool
}

// MARK: - Provider

struct OrderOfPlayProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrderOfPlayEntry {
        OrderOfPlayEntry(
            date: .now,
            centerCourtLive: sampleLiveMatch,
            upcoming: [sampleUpcoming, sampleUpcoming],
            tournamentName: "Wimbledon",
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (OrderOfPlayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            completion(await buildEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrderOfPlayEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func buildEntry() async -> OrderOfPlayEntry {
        do {
            let payload = try await WidgetAPIService.fetchWidgetData()

            let players = payload.liveMatches.flatMap { [$0.player1, $0.player2] }
                + payload.upcomingMatches.flatMap { [$0.player1, $0.player2] }
            _ = await WidgetImageCache.cacheImages(for: players)

            let centerLive = OrderOfPlaySelector.centerCourtLiveMatch(from: payload)
            let upcoming = OrderOfPlaySelector.nextUpcomingMatches(from: payload, limit: 2)
            let tournament = centerLive?.tournament
                ?? upcoming.first?.tournament
                ?? AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoriteGrandSlam)

            return OrderOfPlayEntry(
                date: .now,
                centerCourtLive: centerLive,
                upcoming: upcoming,
                tournamentName: tournament,
                isPlaceholder: false
            )
        } catch {
            return OrderOfPlayEntry(
                date: .now,
                centerCourtLive: nil,
                upcoming: [],
                tournamentName: nil,
                isPlaceholder: false
            )
        }
    }

    private var sampleLiveMatch: WidgetLiveMatch {
        WidgetLiveMatch(
            id: 1,
            tour: "ATP",
            tournament: "Wimbledon",
            court: "Centre Court",
            status: "LIVE",
            score: "6-4 4-4",
            gameScore: "30-15",
            server: 2,
            player1: WidgetPlayer(id: 1, name: "Carlos Alcaraz", country: "ESP", imageUrl: nil),
            player2: WidgetPlayer(id: 2, name: "Jannik Sinner", country: "ITA", imageUrl: nil)
        )
    }

    private var sampleUpcoming: WidgetUpcomingMatch {
        WidgetUpcomingMatch(
            id: 2,
            tour: "ATP",
            tournament: "Wimbledon",
            court: "Centre Court",
            round: "SF",
            startTime: Date().addingTimeInterval(7200),
            player1: WidgetPlayer(id: 3, name: "Novak Djokovic", country: "SRB", imageUrl: nil),
            player2: WidgetPlayer(id: 4, name: "Daniil Medvedev", country: "RUS", imageUrl: nil)
        )
    }
}

enum OrderOfPlaySelector {
    static func centerCourtLiveMatch(from payload: WidgetDataPayload) -> WidgetLiveMatch? {
        if let center = payload.liveMatches.first(where: isCenterCourt) {
            return center
        }
        return payload.liveMatches.first
    }

    static func nextUpcomingMatches(from payload: WidgetDataPayload, limit: Int) -> [WidgetUpcomingMatch] {
        let now = Date()
        let centerUpcoming = payload.upcomingMatches
            .filter { match in
                guard let start = match.startTime else { return isCenterCourt(match) }
                return start > now
            }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }

        let center = centerUpcoming.filter(isCenterCourt)
        let pool = center.isEmpty ? centerUpcoming : center
        return Array(pool.prefix(limit))
    }

    private static func isCenterCourt(_ match: WidgetLiveMatch) -> Bool {
        courtName(match.court).contains("center") || courtName(match.court).contains("centre")
    }

    private static func isCenterCourt(_ match: WidgetUpcomingMatch) -> Bool {
        courtName(match.court).contains("center") || courtName(match.court).contains("centre")
    }

    private static func courtName(_ court: String?) -> String {
        court?.lowercased() ?? ""
    }
}

// MARK: - Widget

struct OrderOfPlayWidget: Widget {
    let kind = "OrderOfPlayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrderOfPlayProvider()) { entry in
            OrderOfPlayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.midnightGreen
                }
        }
        .configurationDisplayName("Order of Play")
        .description("Centre Court live action and upcoming matches.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - View

struct OrderOfPlayWidgetView: View {
    let entry: OrderOfPlayEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetTheme.emeraldGreen.opacity(0.35), WidgetTheme.midnightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                header
                glassCard {
                    if let live = entry.centerCourtLive {
                        liveMatchCard(live)
                    } else {
                        emptyLiveCard
                    }
                }

                ForEach(entry.upcoming) { match in
                    glassCard {
                        upcomingRow(match)
                    }
                }

                if entry.upcoming.isEmpty && entry.centerCourtLive == nil {
                    glassCard {
                        Text("No matches on court right now.")
                            .font(WidgetTheme.roundedFont(.subheadline))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Order of Play")
                .font(WidgetTheme.roundedFont(.title3, weight: .bold))
                .foregroundStyle(.white)
            if let tournament = entry.tournamentName, !tournament.isEmpty {
                Text(tournament)
                    .font(WidgetTheme.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(WidgetTheme.opticYellow.opacity(0.9))
            }
        }
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(WidgetTheme.opticYellow.opacity(0.12), lineWidth: 1)
            }
    }

    @ViewBuilder
    private func liveMatchCard(_ match: WidgetLiveMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Centre Court", systemImage: "tennisball.fill")
                    .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(WidgetTheme.opticYellow)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(WidgetTheme.opticYellow).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(WidgetTheme.roundedFont(.caption2, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)
                }
            }

            matchPlayerRow(
                player: match.player1,
                score: match.score,
                isServing: match.server == 1
            )
            matchPlayerRow(
                player: match.player2,
                score: match.gameScore,
                isServing: match.server == 2
            )
        }
    }

    private var emptyLiveCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Centre Court")
                .font(WidgetTheme.roundedFont(.caption, weight: .semibold))
                .foregroundStyle(WidgetTheme.opticYellow)
            Text("No live match")
                .font(WidgetTheme.roundedFont(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func upcomingRow(_ match: WidgetUpcomingMatch) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.court ?? "Upcoming")
                    .font(WidgetTheme.roundedFont(.caption2, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let start = match.startTime {
                    Text(start, style: .time)
                        .font(WidgetTheme.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(WidgetTheme.opticYellow.opacity(0.85))
                }
            }

            HStack {
                Text(match.player1.name.components(separatedBy: " ").last ?? match.player1.name)
                    .font(WidgetTheme.roundedFont(.subheadline, weight: .semibold))
                Text("vs")
                    .font(WidgetTheme.roundedFont(.caption))
                    .foregroundStyle(.white.opacity(0.45))
                Text(match.player2.name.components(separatedBy: " ").last ?? match.player2.name)
                    .font(WidgetTheme.roundedFont(.subheadline, weight: .semibold))
            }
            .foregroundStyle(.white)
            .lineLimit(1)

            if let round = match.round {
                Text(round)
                    .font(WidgetTheme.roundedFont(.caption2))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func matchPlayerRow(player: WidgetPlayer, score: String?, isServing: Bool) -> some View {
        HStack(spacing: 8) {
            playerAvatar(player)
            Text(player.name)
                .font(WidgetTheme.roundedFont(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if isServing {
                Circle()
                    .fill(WidgetTheme.opticYellow)
                    .frame(width: 8, height: 8)
            }
            Spacer(minLength: 0)
            if let score {
                Text(score)
                    .font(WidgetTheme.roundedFont(.subheadline, weight: .bold))
                    .foregroundStyle(WidgetTheme.opticYellow)
            }
        }
    }

    @ViewBuilder
    private func playerAvatar(_ player: WidgetPlayer) -> some View {
        if let id = player.id,
           let path = AppGroupConstants.playerImagesDirectory?.appendingPathComponent("\(id).jpg").path,
           let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(WidgetTheme.emeraldGreen.opacity(0.6))
                .frame(width: 28, height: 28)
                .overlay {
                    Text(player.name.prefix(1))
                        .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                        .foregroundStyle(WidgetTheme.opticYellow)
                }
        }
    }
}

// MARK: - Preview helpers

extension WidgetUpcomingMatch {
    init(
        id: Int?,
        tour: String,
        tournament: String?,
        court: String?,
        round: String?,
        startTime: Date?,
        player1: WidgetPlayer,
        player2: WidgetPlayer
    ) {
        self.id = id
        self.tour = tour
        self.tournament = tournament
        self.court = court
        self.round = round
        self.startTime = startTime
        self.player1 = player1
        self.player2 = player2
    }
}

#Preview(as: .systemLarge) {
    OrderOfPlayWidget()
} timeline: {
    OrderOfPlayEntry(
        date: .now,
        centerCourtLive: WidgetLiveMatch(
            id: 1,
            tour: "ATP",
            tournament: "Wimbledon",
            court: "Centre Court",
            status: "LIVE",
            score: "6-4 4-4",
            gameScore: "30-15",
            server: 1,
            player1: WidgetPlayer(id: 1, name: "Carlos Alcaraz", country: "ESP", imageUrl: nil),
            player2: WidgetPlayer(id: 2, name: "Jannik Sinner", country: "ITA", imageUrl: nil)
        ),
        upcoming: [],
        tournamentName: "Wimbledon",
        isPlaceholder: true
    )
}
