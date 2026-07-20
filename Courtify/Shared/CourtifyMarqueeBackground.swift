import SwiftUI

/// GPU-friendly infinite marquee used on the onboarding splash and paywall.
/// Renders live mini widget cards so splash always matches the gallery redesign.
///
/// Critical layout rule: each scrolling strip must be **leading-aligned** inside a
/// clipped viewport. Centering a wide `HStack` and offsetting it leaves empty
/// midnight gutters (especially top-leading) as the phase wraps.
struct CourtifyMarqueeBackground: View {
    var opacity: Double = 0.74

    private let rowCount = 8
    private let cardHeight: CGFloat = 128
    /// Slightly airier than the gallery — paywall reads more premium when cards breathe.
    private let rowSpacing: CGFloat = 22
    private let duration: Double = 30

    /// Palette key: a=AO sky, f=RG clay, w=Wimbledon purple/green, u=US Open night blue.
    /// Rows 0–1 and 6–7 are the most visible on paywall — pack torso favorite cards there.
    private let rows: [[MarqueeCard]] = [
        // Top — dense torsos
        [
            .favorite(playerID: "alcaraz", slam: .frenchOpen),
            .favoriteMedium(playerID: "sinner", slam: .usOpen),
            .favorite(playerID: "djokovic", slam: .australianOpen),
            .favoriteMedium(playerID: "swiatek", slam: .wimbledon),
            .favorite(playerID: "sabalenka", slam: .frenchOpen),
            .favoriteMedium(playerID: "zverev", slam: .australianOpen),
        ],
        [
            .favoriteMedium(playerID: "alcaraz", slam: .usOpen),
            .favorite(playerID: "gauff", slam: .wimbledon),
            .favoriteMedium(playerID: "djokovic", slam: .frenchOpen),
            .favorite(playerID: "sinner", slam: .australianOpen),
            .favoriteMedium(playerID: "rybakina", slam: .usOpen),
            .favorite(playerID: "medvedev", slam: .wimbledon),
        ],
        // Mid — mix of classics / live / standings
        [
            .classic(2, slam: .frenchOpen),
            .favorite(playerID: "sabalenka", slam: .australianOpen),
            .order(slam: .usOpen),
            .favoriteMedium(playerID: "djokovic", slam: .wimbledon),
            .live(slam: .wimbledon),
            .calendar(slam: .australianOpen),
        ],
        [
            .favorite(playerID: "gauff", slam: .usOpen),
            .classic(3, slam: .wimbledon),
            .nextSmall(slam: .australianOpen),
            .favoriteMedium(playerID: "alcaraz", slam: .frenchOpen),
            .lockCountdown,
            .classic(4, slam: .wimbledon),
        ],
        [
            .favoriteMedium(playerID: "swiatek", slam: .australianOpen),
            .live(slam: .frenchOpen),
            .favorite(playerID: "sinner", slam: .wimbledon),
            .classic(0, slam: .wimbledon),
            .order(slam: .australianOpen),
            .countdown(slam: .wimbledon),
        ],
        [
            .classic(1, slam: .australianOpen),
            .favorite(playerID: "alcaraz", slam: .usOpen),
            .atpMedium(slam: .usOpen),
            .favoriteMedium(playerID: "sabalenka", slam: .frenchOpen),
            .nextSmall(slam: .frenchOpen),
            .wtaMedium(slam: .australianOpen),
        ],
        // Bottom — dense torsos again
        [
            .favorite(playerID: "djokovic", slam: .frenchOpen),
            .favoriteMedium(playerID: "pegula", slam: .australianOpen),
            .favorite(playerID: "swiatek", slam: .usOpen),
            .favoriteMedium(playerID: "alcaraz", slam: .wimbledon),
            .favorite(playerID: "zverev", slam: .frenchOpen),
            .favoriteMedium(playerID: "gauff", slam: .usOpen),
        ],
        [
            .favoriteMedium(playerID: "sinner", slam: .australianOpen),
            .favorite(playerID: "sabalenka", slam: .wimbledon),
            .favoriteMedium(playerID: "medvedev", slam: .usOpen),
            .favorite(playerID: "rybakina", slam: .frenchOpen),
            .favoriteMedium(playerID: "djokovic", slam: .australianOpen),
            .favorite(playerID: "alcaraz", slam: .usOpen),
        ],
    ]

    var body: some View {
        GeometryReader { geo in
            // Prefer window insets — if this reader is under ignoresSafeArea,
            // geo.safeAreaInsets are zeroed and we'd leave a status-bar band.
            let top = max(geo.safeAreaInsets.top, CourtifyLayout.topSafeInset)
            let bottom = max(geo.safeAreaInsets.bottom, 34)
            let width = geo.size.width
            // Grow the laid-out height by the insets we offset into, so
            // GeometryReader's clip doesn't eat the bottom after shifting up.
            let laidOutHeight = geo.size.height + (geo.safeAreaInsets.top > 0 ? top : 0)
                + (geo.safeAreaInsets.bottom > 0 ? bottom : 0)
            let contentHeight = CGFloat(rowCount) * cardHeight
                + CGFloat(rowCount - 1) * rowSpacing
            let yStart: CGFloat = geo.safeAreaInsets.top > 0 ? (-top - 6) : -6

            VStack(spacing: rowSpacing) {
                ForEach(0..<rowCount, id: \.self) { row in
                    MarqueeLiveRow(
                        cards: rows[row % rows.count],
                        cardHeight: cardHeight,
                        duration: duration + Double(row) * 3.8,
                        phaseFraction: Double((row * 3) % 7) * 0.13,
                        reverse: row % 2 == 1
                    )
                }
            }
            .frame(
                width: width,
                height: max(laidOutHeight + cardHeight, contentHeight),
                alignment: .topLeading
            )
            .offset(y: yStart)
            .opacity(opacity)
        }
        .allowsHitTesting(false)
    }
}

private enum MarqueeCard: Identifiable {
    case favorite(playerID: String, slam: GrandSlam)
    case favoriteMedium(playerID: String, slam: GrandSlam)
    case nextSmall(slam: GrandSlam)
    case countdown(slam: GrandSlam)
    case nextLarge(slam: GrandSlam)
    case calendar(slam: GrandSlam)
    case atpMedium(slam: GrandSlam)
    case wtaMedium(slam: GrandSlam)
    case live(slam: GrandSlam)
    case order(slam: GrandSlam)
    case classic(Int, slam: GrandSlam)
    case lockRank(playerID: String)
    case lockCountdown, lockNext

    var id: String {
        switch self {
        case .favorite(let playerID, let slam): return "favorite-\(playerID)-\(slam.rawValue)"
        case .favoriteMedium(let playerID, let slam): return "favorite-medium-\(playerID)-\(slam.rawValue)"
        case .nextSmall(let slam): return "next-small-\(slam.rawValue)"
        case .countdown(let slam): return "countdown-\(slam.rawValue)"
        case .nextLarge(let slam): return "next-large-\(slam.rawValue)"
        case .calendar(let slam): return "calendar-\(slam.rawValue)"
        case .atpMedium(let slam): return "atp-medium-\(slam.rawValue)"
        case .wtaMedium(let slam): return "wta-medium-\(slam.rawValue)"
        case .live(let slam): return "live-\(slam.rawValue)"
        case .order(let slam): return "order-\(slam.rawValue)"
        case .classic(let index, let slam): return "classic-\(index)-\(slam.rawValue)"
        case .lockRank(let playerID): return "lock-rank-\(playerID)"
        case .lockCountdown: return "lock-countdown"
        case .lockNext: return "lock-next"
        }
    }

    var width: CGFloat {
        switch self {
        case .favorite, .nextSmall, .live, .classic, .lockRank, .lockCountdown:
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
    /// 0...1 — stable phase so rows don't share the same seam.
    let phaseFraction: Double
    var reverse: Bool = false

    private let gap: CGFloat = 22

    private var travelDistance: CGFloat {
        cards.reduce(0) { $0 + $1.width + gap }
    }

    private var strip: some View {
        HStack(spacing: gap) {
            ForEach(cards) { card in
                marqueePreview(card)
                    .frame(width: card.width, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    // Keep shadows inside the card bounds so `.clipped()` on the
                    // viewport doesn't carve a dark “cutoff” halo at the edges.
                    .shadow(color: .black.opacity(0.34), radius: 8, y: 4)
            }
        }
    }

    var body: some View {
        // TimelineView gives a continuous modulo offset — no repeatForever seam flash.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let travel = max(travelDistance, 1)
            let phase = CGFloat(phaseFraction.truncatingRemainder(dividingBy: 1)) * travel
            let cycle = context.date.timeIntervalSinceReferenceDate / max(duration, 0.1)
            let progress = cycle - floor(cycle) // 0...1
            let delta = CGFloat(progress) * travel
            let x: CGFloat = reverse ? (-phase + delta) : (-phase - delta)
            // Wrap into (-travel, 0] so we always sit on duplicated strip content.
            let wrapped = x.truncatingRemainder(dividingBy: travel)
            let offsetX = wrapped > 0 ? wrapped - travel : wrapped

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)
                .overlay(alignment: .leading) {
                    HStack(spacing: 0) {
                        strip
                        strip
                        strip
                    }
                    .offset(x: offsetX)
                }
                .clipped()
        }
    }

    @ViewBuilder
    private func marqueePreview(_ card: MarqueeCard) -> some View {
        let tour: TourPreference = .atp
        let rankings = WidgetPreviewSamples.rankings(for: .atp)

        switch card {
        case .favorite(let playerID, let slam):
            FavoritePlayerWidgetView(
                player: MarqueeShowcaseData.player(id: playerID),
                widgetID: "favorite",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .favoriteMedium(let playerID, let slam):
            FavoritePlayerMediumWidgetView(
                player: MarqueeShowcaseData.player(id: playerID),
                widgetID: "favorite-medium",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .nextSmall(let slam):
            NextTournamentSmallView(tour: tour, forceSlam: slam)
        case .countdown(let slam):
            TournamentCountdownView(tour: tour, forceSlam: slam)
        case .nextLarge(let slam):
            NextTournamentLargeView(tour: tour, forceSlam: slam)
        case .calendar(let slam):
            SeasonCalendarView(tour: tour, forceSlam: slam)
        case .atpMedium(let slam):
            RankingsWidgetView(
                tour: .atp,
                entries: rankings,
                limit: 5,
                widgetID: "atp-medium",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .wtaMedium(let slam):
            RankingsWidgetView(
                tour: .wta,
                entries: WidgetPreviewSamples.rankings(for: .wta),
                limit: 5,
                widgetID: "wta-medium",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .live(let slam):
            LiveScoresWidgetView(
                match: MarqueeShowcaseData.modernLiveMatch,
                widgetID: "live",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .classic(let index, let slam):
            LiveScoresWidgetView(
                match: MarqueeShowcaseData.classicMatch(at: index),
                widgetID: "live",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .order(let slam):
            OrderOfPlayListView(
                matches: WidgetPreviewSamples.upcomingMatches,
                widgetID: "order",
                forceAccent: Color(hex: slam.accentColor)
            )
        case .lockRank(let playerID):
            LockScreenCircularRankView(
                player: MarqueeShowcaseData.player(id: playerID),
                showsPreviewPlate: true
            )
            .padding(10)
        case .lockCountdown:
            LockScreenCircularCountdownView(tour: tour, showsPreviewPlate: true)
                .padding(10)
        case .lockNext:
            LockScreenRectangularNextView(tour: tour, showsPreviewPlate: true)
        }
    }
}
