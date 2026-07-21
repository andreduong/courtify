import WidgetKit
import SwiftUI

// MARK: - Entry

struct TournamentEntry: TimelineEntry {
    let date: Date
    let tour: TourPreference
    let isLocked: Bool
    /// System widget gallery / placeholder — use Wimbledon showcase copy.
    var isShowcase: Bool = false
}

// MARK: - Provider

struct TournamentProvider: TimelineProvider {
    func placeholder(in context: Context) -> TournamentEntry {
        TournamentEntry(date: .now, tour: LockScreenGallerySamples.tour, isLocked: false, isShowcase: true)
    }

    private func lockedEntry() -> TournamentEntry {
        TournamentEntry(date: .now, tour: WidgetPayloadReader.preferredTour(), isLocked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TournamentEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        guard AppGroupConstants.widgetAccessEnabled else {
            completion(lockedEntry())
            return
        }
        completion(TournamentEntry(date: .now, tour: WidgetPayloadReader.preferredTour(), isLocked: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TournamentEntry>) -> Void) {
        let entry: TournamentEntry
        if AppGroupConstants.widgetAccessEnabled {
            entry = TournamentEntry(date: .now, tour: WidgetPayloadReader.preferredTour(), isLocked: false)
        } else {
            entry = lockedEntry()
        }
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Widget

struct NextTournamentWidget: Widget {
    let kind = WidgetTimelineRefresher.nextTournamentKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            Group {
                if entry.isLocked {
                    WidgetLockedView()
                } else {
                    NextTournamentWidgetContent(tour: entry.tour)
                }
            }
            .courtifyHomeWidgetStampEnabled()
        }
        .configurationDisplayName("Next tournament")
        .description("The next major on your tour.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// Separate kind so Home Screen picker lists "Tournament countdown" like Widgets Collection.
struct TournamentCountdownWidget: Widget {
    let kind = WidgetTimelineRefresher.tournamentCountdownKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            Group {
                if entry.isLocked {
                    WidgetLockedView()
                } else {
                    TournamentCountdownView(tour: entry.tour, widgetID: "countdown")
                }
            }
            .courtifyHomeWidgetStampEnabled()
        }
        .configurationDisplayName("Tournament countdown")
        .description("Days, hours, and minutes until the next major.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private struct NextTournamentWidgetContent: View {
    @Environment(\.widgetFamily) private var family
    let tour: TourPreference

    var body: some View {
        switch family {
        case .systemLarge:
            NextTournamentLargeView(tour: tour, widgetID: "next-large")
        default:
            NextTournamentSmallView(tour: tour, widgetID: "next-small")
        }
    }
}

struct SeasonCalendarWidget: Widget {
    let kind = WidgetTimelineRefresher.seasonCalendarKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TournamentProvider()) { entry in
            Group {
                if entry.isLocked {
                    WidgetLockedView()
                } else {
                    SeasonCalendarView(tour: entry.tour, widgetID: "calendar")
                }
            }
            .courtifyHomeWidgetStampEnabled()
        }
        .configurationDisplayName("Season calendar")
        .description("Full 2026 tournament schedule for your tour.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    NextTournamentWidget()
} timeline: {
    TournamentEntry(date: .now, tour: .atp, isLocked: false)
}

#Preview(as: .systemLarge) {
    SeasonCalendarWidget()
} timeline: {
    TournamentEntry(date: .now, tour: .atp, isLocked: false)
}
