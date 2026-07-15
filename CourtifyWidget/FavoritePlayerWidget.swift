import WidgetKit
import SwiftUI

// MARK: - Entry

struct FavoritePlayerEntry: TimelineEntry {
    let date: Date
    let player: TennisPlayer?
}

// MARK: - Provider

struct FavoritePlayerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FavoritePlayerEntry {
        FavoritePlayerEntry(date: .now, player: WidgetPreviewSamples.favoritePlayer)
    }

    func snapshot(for configuration: SelectFavoritePlayerIntent, in context: Context) async -> FavoritePlayerEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return makeEntry(for: configuration)
    }

    func timeline(for configuration: SelectFavoritePlayerIntent, in context: Context) async -> Timeline<FavoritePlayerEntry> {
        let entry = makeEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(WidgetPayloadReader.nextRefreshDate()))
    }

    private func makeEntry(for configuration: SelectFavoritePlayerIntent) -> FavoritePlayerEntry {
        syncWidgetIntentIfChanged(configuration)

        let selectedID = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoritePlayerID) ?? ""
        let payload = WidgetPayloadReader.loadCached()
        let player = FavoritePlayerCatalog.resolvedPlayer(id: selectedID, payload: payload)
            ?? FavoritePlayerCatalog.resolvedFavoritePlayer(payload: payload)
        return FavoritePlayerEntry(date: .now, player: player)
    }

    /// Only promote widget-intent changes when the user edits the home-screen widget.
    /// Stale default intent values must not overwrite in-app picker selections.
    private func syncWidgetIntentIfChanged(_ configuration: SelectFavoritePlayerIntent) {
        let intentID = configuration.player?.id ?? ""
        guard !intentID.isEmpty else { return }

        let lastSeenIntentID = AppGroupConstants.userDefaults.string(
            forKey: AppGroupConstants.Keys.favoritePlayerWidgetIntentID
        ) ?? ""

        guard intentID != lastSeenIntentID else { return }

        AppGroupConstants.userDefaults.set(intentID, forKey: AppGroupConstants.Keys.favoritePlayerWidgetIntentID)
        AppGroupConstants.updateFavoritePlayer(intentID)
    }
}

// MARK: - Widget

struct FavoritePlayerWidget: Widget {
    let kind = WidgetTimelineRefresher.favoritePlayerKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFavoritePlayerIntent.self, provider: FavoritePlayerProvider()) { entry in
            FavoritePlayerWidgetView(player: entry.player)
        }
        .configurationDisplayName("Favorite player")
        .description("Your favorite player's rank and season record.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    FavoritePlayerWidget()
} timeline: {
    FavoritePlayerEntry(date: .now, player: WidgetPreviewSamples.favoritePlayer)
}
