import WidgetKit
import SwiftUI

// MARK: - Entry

struct LiveScoresEntry: TimelineEntry {
    let date: Date
    let match: WidgetLiveMatch?
    let isLocked: Bool
}

// MARK: - Provider

struct LiveScoresProvider: TimelineProvider {
    func placeholder(in context: Context) -> LiveScoresEntry {
        LiveScoresEntry(date: .now, match: LockScreenGallerySamples.liveMatch, isLocked: false)
    }

    private func lockedEntry() -> LiveScoresEntry {
        LiveScoresEntry(date: .now, match: nil, isLocked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LiveScoresEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LiveScoresEntry>) -> Void) {
        let entry = buildEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func buildEntry() -> LiveScoresEntry {
        guard AppGroupConstants.widgetAccessEnabled else {
            return lockedEntry()
        }
        let payload = WidgetPayloadReader.loadPayload()
        return LiveScoresEntry(date: .now, match: payload?.liveMatches.first, isLocked: false)
    }
}

// MARK: - Widget

struct LiveScoresWidget: Widget {
    let kind = WidgetTimelineRefresher.liveScoresKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LiveScoresProvider()) { entry in
            Group {
                if entry.isLocked {
                    WidgetLockedView()
                } else {
                    LiveScoresWidgetView(match: entry.match)
                }
            }
            .courtifyHomeWidgetStampEnabled()
        }
        .configurationDisplayName("Live scores")
        .description("Live match scores from the tour.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    LiveScoresWidget()
} timeline: {
    LiveScoresEntry(date: .now, match: WidgetPreviewSamples.liveMatch, isLocked: false)
}
