import WidgetKit
import SwiftUI

// MARK: - Entry

struct FavoritePlayerEntry: TimelineEntry {
    let date: Date
    let player: TennisPlayer?
}

// MARK: - Provider

struct FavoritePlayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritePlayerEntry {
        FavoritePlayerEntry(date: .now, player: WidgetPreviewSamples.favoritePlayer)
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritePlayerEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(FavoritePlayerEntry(date: .now, player: WidgetPayloadReader.favoritePlayer()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritePlayerEntry>) -> Void) {
        let entry = FavoritePlayerEntry(date: .now, player: WidgetPayloadReader.favoritePlayer())
        completion(Timeline(entries: [entry], policy: .after(WidgetPayloadReader.nextRefreshDate())))
    }
}

// MARK: - Widget

struct FavoritePlayerWidget: Widget {
    let kind = WidgetTimelineRefresher.favoritePlayerKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritePlayerProvider()) { entry in
            FavoritePlayerWidgetView(player: entry.player)
        }
        .configurationDisplayName("Favorite player")
        .description("Your favorite player's bundled rank and season record.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    FavoritePlayerWidget()
} timeline: {
    FavoritePlayerEntry(date: .now, player: WidgetPreviewSamples.favoritePlayer)
}
