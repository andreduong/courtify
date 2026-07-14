import SwiftUI

struct ScheduleView: View {
    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @State private var selectedTour: TourPreference = .atp
    @State private var now = Date()
    @State private var tourScrollGeneration = 0

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var events: [TournamentEvent] {
        TournamentCalendar.events(for: selectedTour)
    }

    private var heroEvent: TournamentEvent? {
        TournamentCalendar.nextMajor(for: selectedTour)
    }

    private var upcomingEventID: String? {
        let today = Calendar.current.startOfDay(for: now)
        return events.first(where: { $0.endDate >= today })?.id
    }

    var body: some View {
        Group {
            if heroEvent != nil {
                CourtifyHeroScrollScreen(
                    heroHeight: CourtifyLayout.scheduleHeroHeight,
                    scrollTrigger: tourScrollGeneration,
                    onScroll: { proxy in
                        scrollToUpcoming(proxy, animated: tourScrollGeneration > 0)
                    },
                    heroBackground: { heroBackground },
                    heroContent: { heroContent },
                    listContent: { tournamentListContent }
                )
            }
        }
        .onAppear {
            if let pref = TourPreference(rawValue: tourPreferenceRaw), pref != .both {
                selectedTour = pref == .wta ? .wta : .atp
            }
        }
        .onChange(of: selectedTour) { _, _ in
            tourScrollGeneration += 1
        }
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let event = heroEvent {
            ZStack {
                if let imageName = event.heroImageName {
                    CachedBundledImage(name: imageName, contentMode: .fill)
                        .blur(radius: 24)
                        .scaleEffect(1.1)
                } else {
                    LinearGradient(
                        colors: [ThemeManager.emeraldGreen.opacity(0.8), ThemeManager.midnightGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                LinearGradient(
                    colors: [.black.opacity(0.15), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private var heroContent: some View {
        if let event = heroEvent {
            let countdown = TournamentCalendar.countdown(to: event)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TourPillToggle(selectedTour: $selectedTour)
                    Spacer()
                }

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 10) {
                    LastUpdatedLabel(date: nil, prefix: "2026 calendar")

                    Text("2026 \(selectedTour.rawValue) Schedule")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))

                    Text(event.shortName + " · " + event.location)
                        .font(ThemeManager.roundedFont(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    Text(event.dateRangeLabel)
                        .font(ThemeManager.roundedFont(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if event.startDate > now {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tournament starts in")
                                .font(ThemeManager.roundedFont(.caption, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))

                            HStack(spacing: 16) {
                                countdownUnit(value: countdown.days, label: "DAYS")
                                countdownUnit(value: countdown.hours, label: "HOURS")
                                countdownUnit(value: countdown.minutes, label: "MINUTES")
                            }
                        }
                    } else {
                        Text(event.tier.rawValue.uppercased())
                            .font(ThemeManager.roundedFont(.caption, weight: .bold))
                            .foregroundStyle(ThemeManager.opticYellow)
                    }
                }
                .padding(.bottom, CourtifyLayout.heroListOverlap + 24)
            }
        }
    }

    @ViewBuilder
    private var tournamentListContent: some View {
        ForEach(events) { event in
            TournamentRow(event: event, isPast: event.endDate < Calendar.current.startOfDay(for: now))
                .id(event.id)
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(ThemeManager.roundedFont(.title2, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func scrollToUpcoming(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let id = upcomingEventID else { return }
        let action = { proxy.scrollTo(id, anchor: .top) }
        if animated {
            withAnimation(CourtifyMotion.screen) { action() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { action() }
        }
    }
}

private struct TournamentRow: View {
    let event: TournamentEvent
    let isPast: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(event.listDateLabel)
                .font(ThemeManager.roundedFont(.caption, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(isPast ? Color.gray.opacity(0.35) : ThemeManager.midnightGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isPast {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ThemeManager.emeraldGreen)
                    }
                    Text(event.name)
                        .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                        .foregroundStyle(isPast ? .gray : ThemeManager.midnightGreen)
                }

                Text("\(event.shortName) · \(event.location) · \(event.surface)")
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.gray)

                Text(event.tier.rawValue)
                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.8))
            }

            Spacer()

            Image(systemName: "tennisball")
                .font(.title3)
                .foregroundStyle(.gray.opacity(0.25))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    ScheduleView()
}
