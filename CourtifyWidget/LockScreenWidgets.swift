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

// MARK: - Badges (circular + rectangular)

struct LockScreenBadgeWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenBadgeKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if entry.isLocked {
                        LockScreenLockedContainer()
                    } else {
                        LockScreenBadgeContainer(slam: LockScreenFavorites.favoriteSlam)
                    }
                }
            }
        }
        .configurationDisplayName("Badges")
        .description("Style your Lock Screen with Grand Slam badges. Premium.")
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
                LockScreenCircularRankView(player: entry.player)
            }
        }
        .configurationDisplayName("Favorite rank")
        .description("Your player's world ranking on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Favorite player stats (rectangular)

struct LockScreenFavoriteWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenFavoriteKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFavoritePlayerIntent.self, provider: FavoritePlayerProvider()) { entry in
            LockScreenAccessoryContainer {
                Group {
                    if AppGroupConstants.widgetAccessEnabled {
                        LockScreenRectangularFavoriteView(player: entry.player)
                    } else {
                        LockScreenLockedRectangular()
                    }
                }
            }
        }
        .configurationDisplayName("Favorite player")
        .description("Rank and season record for your player. Premium.")
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
                            player: LockScreenFavorites.favoritePlayer,
                            tour: entry.tour
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
                        LockScreenCircularCountdownView(tour: entry.tour)
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
                        LockScreenRectangularNextView(tour: entry.tour)
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
                        LockScreenRectangularLiveView(match: entry.match)
                    }
                }
            }
        }
        .configurationDisplayName("Live score")
        .description("Live match score on the Lock Screen. Premium.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Locked placeholders (Subscribe to PREMIUM)

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

struct LockScreenLockedCircular: View {
    var body: some View {
        ZStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

struct LockScreenLockedRectangular: View {
    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Subscribe to")
                        .font(WidgetTheme.roundedFont(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    PremiumWordmark(size: 15)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }
}
