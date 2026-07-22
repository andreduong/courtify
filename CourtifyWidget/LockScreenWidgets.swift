import WidgetKit
import SwiftUI

// MARK: - Helpers

private enum LockScreenFavorites {
    static var favoriteSlam: GrandSlam? {
        let raw = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoriteGrandSlam) ?? ""
        return GrandSlam(rawValue: raw)
    }

    static var favoritePlayer: TennisPlayer? {
        let selectedID = AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoritePlayerID) ?? ""
        let payload = WidgetPayloadReader.loadCached()
        return FavoritePlayerCatalog.resolvedPlayer(id: selectedID, payload: payload)
            ?? FavoritePlayerCatalog.resolvedFavoritePlayer(payload: payload)
    }
}

private struct LockScreenAccessoryContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .containerBackground(for: .widget) {
                AccessoryWidgetBackground()
            }
    }
}

// MARK: - Badge entry / provider (showcase = Wimbledon in system picker)

private struct LockScreenBadgeEntry: TimelineEntry {
    let date: Date
    let slam: GrandSlam?
    let isLocked: Bool
}

private struct LockScreenBadgeProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenBadgeEntry {
        LockScreenBadgeEntry(date: .now, slam: LockScreenGallerySamples.slam, isLocked: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenBadgeEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenBadgeEntry>) -> Void) {
        let entry = buildEntry()
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func buildEntry() -> LockScreenBadgeEntry {
        guard AppGroupConstants.widgetAccessEnabled else {
            return LockScreenBadgeEntry(date: .now, slam: nil, isLocked: true)
        }
        return LockScreenBadgeEntry(
            date: .now,
            slam: LockScreenFavorites.favoriteSlam ?? LockScreenGallerySamples.slam,
            isLocked: false
        )
    }
}

// MARK: - Favorite stats entry / provider (showcase = Alcaraz)

private struct LockScreenFavoriteEntry: TimelineEntry {
    let date: Date
    let player: TennisPlayer?
    let isLocked: Bool
}

private struct LockScreenFavoriteProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenFavoriteEntry {
        LockScreenFavoriteEntry(date: .now, player: LockScreenGallerySamples.player, isLocked: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenFavoriteEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenFavoriteEntry>) -> Void) {
        let entry = buildEntry()
        completion(Timeline(entries: [entry], policy: .after(WidgetPayloadReader.nextRefreshDate())))
    }

    private func buildEntry() -> LockScreenFavoriteEntry {
        // Favorite Lock Screen category is free (rank + stats).
        let player = LockScreenFavorites.favoritePlayer ?? LockScreenGallerySamples.player
        return LockScreenFavoriteEntry(date: .now, player: player, isLocked: false)
    }
}

// MARK: - Season / countdown use TournamentProvider (isPreview already unlocked)

// MARK: - Badges (circular + rectangular)

struct LockScreenBadgeWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenBadgeKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenBadgeProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedContainer()
                    } else {
                        LockScreenBadgeContainer(slam: entry.slam)
                    }
                }
            }
        }
        .configurationDisplayName("Lockscreen Badges")
        .description("Grand Slam badges for your Lock Screen. Premium.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct LockScreenBadgeContainer: View {
    @Environment(\.widgetFamily) private var family
    let slam: GrandSlam?

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularBadgeView(slam: slam)
        default:
            LockScreenCircularBadgeView(slam: slam)
        }
    }
}

// MARK: - Favorite rank (free circular)

struct LockScreenRankWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenRankKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFavoritePlayerIntent.self, provider: FavoritePlayerProvider()) { entry in
            LockScreenAccessoryContainer {
                LockScreenCircularRankView(player: entry.player ?? LockScreenGallerySamples.player)
            }
        }
        .configurationDisplayName("Favorite rank")
        .description("Your player's world ranking on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Favorite player stats (rectangular, free with favorite category)

struct LockScreenFavoriteWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenFavoriteKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenFavoriteProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedRectangular()
                    } else {
                        LockScreenRectangularFavoriteView(player: entry.player)
                    }
                }
            }
        }
        .configurationDisplayName("Favorite player")
        .description("Rank and season record for your player.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Season progress (circular + rectangular)

struct LockScreenSeasonWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenSeasonKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedContainer()
                    } else {
                        LockScreenSeasonContainer(
                            player: entry.isShowcase
                                ? LockScreenGallerySamples.player
                                : (LockScreenFavorites.favoritePlayer ?? LockScreenGallerySamples.player),
                            tour: entry.isShowcase ? LockScreenGallerySamples.tour : entry.tour
                        )
                    }
                }
            }
        }
        .configurationDisplayName("Season progress")
        .description("Win rate and Grand Slam progress. Premium.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct LockScreenSeasonContainer: View {
    @Environment(\.widgetFamily) private var family
    let player: TennisPlayer?
    let tour: TourPreference

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularSeasonView(player: player, tour: tour)
        default:
            LockScreenCircularSeasonView(player: player, tour: tour)
        }
    }
}

// MARK: - Tournament countdown (circular)

struct LockScreenCountdownWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenCountdownKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedCircular()
                    } else {
                        LockScreenCircularCountdownView(
                            tour: entry.tour,
                            forceSlam: entry.isShowcase ? LockScreenGallerySamples.slam : nil
                        )
                    }
                }
            }
        }
        .configurationDisplayName("Tournament countdown")
        .description("Days until the next major on your tour. Premium.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Next tournament (rectangular)

struct LockScreenNextWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenNextKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedRectangular()
                    } else {
                        LockScreenRectangularNextView(
                            tour: entry.tour,
                            forceSlam: entry.isShowcase ? LockScreenGallerySamples.slam : nil
                        )
                    }
                }
            }
        }
        .configurationDisplayName("Next tournament")
        .description("Next major name and countdown. Premium.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Live score (rectangular)

struct LockScreenLiveWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenLiveKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LiveScoresProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedRectangular()
                    } else {
                        LockScreenRectangularLiveView(match: entry.match ?? LockScreenGallerySamples.liveMatch)
                    }
                }
            }
        }
        .configurationDisplayName("Live score")
        .description("Live match score on the Lock Screen. Premium.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Locked placeholders (Subscribe to COURTIFY)

private struct LockScreenLockedContainer: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenLockedRectangular()
        default:
            LockScreenLockedCircular()
        }
    }
}

// Locked placeholders live in `Courtify/Shared/LockScreenLockedViews.swift`.
