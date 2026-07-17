import WidgetKit
import SwiftUI

/// Favorite rank — free Lock Screen circular.
struct LockScreenRankWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenRankKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFavoritePlayerIntent.self, provider: FavoritePlayerProvider()) { entry in
            LockScreenCircularRankView(player: entry.player)
                .containerBackground(for: .widget) { WidgetTheme.midnightGreen }
        }
        .configurationDisplayName("Favorite rank")
        .description("Your player's world ranking on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
        .contentMarginsDisabled()
    }
}

/// Tournament countdown — Pro Lock Screen circular.
struct LockScreenCountdownWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenCountdownKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            Group {
                if entry.isLocked {
                    LockScreenLockedCircular()
                } else {
                    LockScreenCircularCountdownView(tour: entry.tour)
                }
            }
            .containerBackground(for: .widget) { WidgetTheme.midnightGreen }
        }
        .configurationDisplayName("Tournament countdown")
        .description("Days until the next major on your tour.")
        .supportedFamilies([.accessoryCircular])
        .contentMarginsDisabled()
    }
}

/// Next tournament — Pro Lock Screen rectangular.
struct LockScreenNextWidget: Widget {
    let kind = WidgetTimelineRefresher.lockScreenNextKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            Group {
                if entry.isLocked {
                    LockScreenLockedRectangular(label: "Premium")
                } else {
                    LockScreenRectangularNextView(tour: entry.tour)
                }
            }
            .containerBackground(for: .widget) { WidgetTheme.midnightGreen }
        }
        .configurationDisplayName("Next tournament")
        .description("Next major name and countdown.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Locked placeholders

struct LockScreenLockedCircular: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 5)
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(6)
    }
}

struct LockScreenLockedRectangular: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(WidgetTheme.opticYellow)
            Text(label)
                .font(WidgetTheme.roundedFont(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }
}
