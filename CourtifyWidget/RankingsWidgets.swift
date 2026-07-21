import WidgetKit
import SwiftUI

// MARK: - Entry

struct RankingsEntry: TimelineEntry {
    let date: Date
    let tour: TourPreference
    let entries: [WidgetRankingEntry]
    let isLocked: Bool
}

// MARK: - Provider

struct RankingsProvider: TimelineProvider {
    let tour: TourPreference

    func placeholder(in context: Context) -> RankingsEntry {
        RankingsEntry(
            date: .now,
            tour: tour,
            entries: WidgetPreviewSamples.rankings(for: tour),
            isLocked: false
        )
    }

    private func lockedEntry() -> RankingsEntry {
        RankingsEntry(date: .now, tour: tour, entries: [], isLocked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RankingsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RankingsEntry>) -> Void) {
        let entry = buildEntry()
        completion(Timeline(entries: [entry], policy: .after(WidgetPayloadReader.nextRefreshDate())))
    }

    private func buildEntry() -> RankingsEntry {
        guard AppGroupConstants.widgetAccessEnabled else {
            return lockedEntry()
        }
        let payload = WidgetPayloadReader.loadPayload()
        let entries: [WidgetRankingEntry]
        switch tour {
        case .atp: entries = payload?.rankings.atp ?? []
        case .wta: entries = payload?.rankings.wta ?? []
        case .both: entries = payload?.rankings.atp ?? []
        }
        return RankingsEntry(date: .now, tour: tour, entries: entries, isLocked: false)
    }
}

// MARK: - Widgets

struct ATPStandingsWidget: Widget {
    let kind = WidgetTimelineRefresher.atpStandingsKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RankingsProvider(tour: .atp)) { entry in
            RankingsWidgetContainer(entry: entry)
        }
        .configurationDisplayName("ATP standings")
        .description("Live ATP top 5 or top 10 rankings.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct WTAStandingsWidget: Widget {
    let kind = WidgetTimelineRefresher.wtaStandingsKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RankingsProvider(tour: .wta)) { entry in
            RankingsWidgetContainer(entry: entry)
        }
        .configurationDisplayName("WTA standings")
        .description("Live WTA top 5 or top 10 rankings.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct RankingsWidgetContainer: View {
    @Environment(\.widgetFamily) private var family
    let entry: RankingsEntry

    private var mediumID: String {
        entry.tour == .wta ? "wta-medium" : "atp-medium"
    }

    private var largeID: String {
        entry.tour == .wta ? "wta-large" : "atp-large"
    }

    var body: some View {
        Group {
            if entry.isLocked {
                WidgetLockedView()
            } else if family == .systemLarge {
                RankingsLargeWidgetView(tour: entry.tour, entries: entry.entries, widgetID: largeID)
            } else {
                RankingsWidgetView(tour: entry.tour, entries: entry.entries, limit: 5, widgetID: mediumID)
            }
        }
        .courtifyHomeWidgetStampEnabled()
    }
}

#Preview(as: .systemMedium) {
    ATPStandingsWidget()
} timeline: {
    RankingsEntry(
        date: .now,
        tour: .atp,
        entries: WidgetPreviewSamples.rankings(for: .atp),
        isLocked: false
    )
}
