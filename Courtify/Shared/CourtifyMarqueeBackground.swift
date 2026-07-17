import SwiftUI

/// GPU-friendly infinite marquee used on the onboarding splash and paywall.
/// Renders live mini widget cards so splash always matches the gallery redesign.
///
/// Critical layout rule: each scrolling strip must be **leading-aligned** inside a
/// clipped viewport. Centering a wide `HStack` and offsetting it leaves empty
/// midnight gutters (especially top-leading) as the phase wraps.
struct CourtifyMarqueeBackground: View {
    var opacity: Double = 0.68

    private let rowCount = 8
    private let cardHeight: CGFloat = 128
    private let rowSpacing: CGFloat = 8
    private let duration: Double = 26

    private let rows: [[MarqueeCard]] = [
        [.favorite, .nextSmall, .live, .countdown, .atpMedium, .order],
        [.wtaMedium, .lockRank, .favoriteMedium, .nextLarge, .calendar, .live],
        [.order, .lockCountdown, .live, .favorite, .countdown, .atpMedium],
        [.atpMedium, .nextSmall, .lockNext, .wtaMedium, .favoriteMedium, .calendar],
        [.calendar, .live, .favorite, .nextLarge, .order, .countdown],
        [.favoriteMedium, .countdown, .atpMedium, .nextSmall, .live, .wtaMedium],
        [.nextLarge, .favorite, .order, .lockRank, .countdown, .live],
        [.live, .calendar, .wtaMedium, .favoriteMedium, .nextSmall, .atpMedium],
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
    /// 0...1 — stable phase so rows don't share the same seam.
    let phaseFraction: Double
    var reverse: Bool = false

    private let gap: CGFloat = 8

    private var travelDistance: CGFloat {
        cards.reduce(0) { $0 + $1.width + gap }
    }

    private var strip: some View {
        HStack(spacing: gap) {
            ForEach(cards) { card in
                marqueePreview(card)
                    .frame(width: card.width, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    // Keep shadows inside the card bounds so `.clipped()` on the
                    // viewport doesn't carve a dark “cutoff” halo at the edges.
                    .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
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
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.35)
                }
                .padding(8)
                .background(WidgetTheme.midnightGreen)
        case .lockCountdown:
            LockScreenCircularCountdownView(tour: tour)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.35)
                }
                .padding(8)
                .background(WidgetTheme.midnightGreen)
        case .lockNext:
            LockScreenRectangularNextView(tour: tour)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.62), lineWidth: 1.2)
                }
        }
    }
}
