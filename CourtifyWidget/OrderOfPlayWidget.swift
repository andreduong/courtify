import WidgetKit
import SwiftUI

// MARK: - Entry

struct OrderOfPlayEntry: TimelineEntry {
    let date: Date
    let matches: [WidgetUpcomingMatch]
    let isLocked: Bool
}

// MARK: - Provider

struct OrderOfPlayProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrderOfPlayEntry {
        OrderOfPlayEntry(date: .now, matches: WidgetPreviewSamples.upcomingMatches, isLocked: false)
    }

    private func lockedEntry() -> OrderOfPlayEntry {
        OrderOfPlayEntry(date: .now, matches: [], isLocked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (OrderOfPlayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrderOfPlayEntry>) -> Void) {
        let entry = buildEntry()
        completion(Timeline(entries: [entry], policy: .after(WidgetPayloadReader.nextRefreshDate())))
    }

    private func buildEntry() -> OrderOfPlayEntry {
        guard AppGroupConstants.widgetAccessEnabled else {
            return lockedEntry()
        }
        let payload = WidgetPayloadReader.loadPayload()
        let now = Date()
        let upcoming = (payload?.upcomingMatches ?? [])
            .filter { match in
                guard let start = match.startTime else { return true }
                return start > now
            }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
        return OrderOfPlayEntry(date: .now, matches: Array(upcoming.prefix(6)), isLocked: false)
    }
}

// MARK: - Widget

struct OrderOfPlayWidget: Widget {
    let kind = WidgetTimelineRefresher.orderOfPlayKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrderOfPlayProvider()) { entry in
            Group {
                if entry.isLocked {
                    WidgetLockedView()
                } else {
                    OrderOfPlayListView(matches: entry.matches)
                }
            }
            .courtifyHomeWidgetStampEnabled()
        }
        .configurationDisplayName("Order of play")
        .description("Upcoming matches across all courts.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    OrderOfPlayWidget()
} timeline: {
    OrderOfPlayEntry(date: .now, matches: WidgetPreviewSamples.upcomingMatches, isLocked: false)
}
