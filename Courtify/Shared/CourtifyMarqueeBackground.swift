import SwiftUI

/// GPU-friendly infinite marquee used on the onboarding splash and paywall.
/// Renders live mini widget cards so splash always matches the gallery redesign.
struct CourtifyMarqueeBackground: View {
    var opacity: Double = 0.55

    private let rowCount = 4
    private let cardHeight: CGFloat = 118
    private let duration: Double = 32

    private let rows: [[MarqueeCard]] = [
        [.favorite, .nextSmall, .live, .countdown, .atpMedium],
        [.wtaMedium, .lockRank, .favoriteMedium, .nextLarge, .calendar],
        [.order, .lockCountdown, .live, .favorite, .countdown],
        [.atpMedium, .nextSmall, .lockNext, .wtaMedium, .favoriteMedium],
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 20) {
                ForEach(0..<rowCount, id: \.self) { row in
                    MarqueeLiveRow(
                        cards: rows[row % rows.count],
                        cardHeight: cardHeight,
                        duration: duration + Double(row) * 5,
                        startOffset: CGFloat(row) * 64,
                        reverse: row % 2 == 1
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -geo.size.height * 0.04)
            .opacity(opacity)
        }
        .allowsHitTesting(false)
    }
}

private enum MarqueeCard: String, Identifiable {
    case favorite, favoriteMedium, nextSmall, countdown, nextLarge, calendar
    case atpMedium, wtaMedium, live, order
    case lockRank, lockCountdown, lockNext

    var id: String { rawValue }

    var width: CGFloat {
        switch self {
        case .favorite, .nextSmall, .live, .lockRank, .lockCountdown:
            return 118
        case .favoriteMedium, .countdown, .atpMedium, .wtaMedium, .lockNext:
            return 220
        case .nextLarge, .calendar, .order:
            return 200
        }
    }
}

private struct MarqueeLiveRow: View {
    let cards: [MarqueeCard]
    let cardHeight: CGFloat
    let duration: Double
    let startOffset: CGFloat
    var reverse: Bool = false

    @State private var animate = false

    private var strip: some View {
        HStack(spacing: 14) {
            ForEach(cards) { card in
                marqueePreview(card)
                    .frame(width: card.width, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            }
        }
    }

    private var travelDistance: CGFloat {
        cards.reduce(0) { $0 + $1.width + 14 }
    }

    var body: some View {
        HStack(spacing: 0) {
            strip
            strip
        }
        .offset(x: offsetX)
        .onAppear {
            animate = false
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .frame(height: cardHeight)
        .clipped()
    }

    private var offsetX: CGFloat {
        let travel = travelDistance
        if reverse {
            return (animate ? 0 : -travel) + startOffset
        }
        return (animate ? -travel : 0) + startOffset
    }

    @ViewBuilder
    private func marqueePreview(_ card: MarqueeCard) -> some View {
        let player = TennisPlayer.topPlayers.first { $0.id == "sinner" }
            ?? TennisPlayer.topPlayers.first
        let tour: TourPreference = .atp
        let rankings = WidgetPreviewSamples.rankings(for: .atp)

        switch card {
        case .favorite:
            FavoritePlayerWidgetView(player: player, widgetID: "favorite")
        case .favoriteMedium:
            FavoritePlayerMediumWidgetView(player: player, widgetID: "favorite-medium")
        case .nextSmall:
            NextTournamentSmallView(tour: tour)
        case .countdown:
            TournamentCountdownView(tour: tour)
        case .nextLarge:
            NextTournamentLargeView(tour: tour)
        case .calendar:
            SeasonCalendarView(tour: tour)
        case .atpMedium:
            RankingsWidgetView(tour: .atp, entries: rankings, limit: 5, widgetID: "atp-medium")
        case .wtaMedium:
            RankingsWidgetView(tour: .wta, entries: WidgetPreviewSamples.rankings(for: .wta), limit: 5, widgetID: "wta-medium")
        case .live:
            LiveScoresWidgetView(match: WidgetPreviewSamples.liveMatch, widgetID: "live")
        case .order:
            OrderOfPlayListView(matches: WidgetPreviewSamples.upcomingMatches, widgetID: "order")
        case .lockRank:
            LockScreenCircularRankView(player: player)
                .clipShape(Circle())
                .padding(8)
                .background(WidgetTheme.midnightGreen)
        case .lockCountdown:
            LockScreenCircularCountdownView(tour: tour)
                .clipShape(Circle())
                .padding(8)
                .background(WidgetTheme.midnightGreen)
        case .lockNext:
            LockScreenRectangularNextView(tour: tour)
        }
    }
}
