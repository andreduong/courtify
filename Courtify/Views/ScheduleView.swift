import SwiftUI

struct ScheduleView: View {
    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var tourPreferenceRaw = TourPreference.atp.rawValue

    @State private var selectedTour: TourPreference = .atp
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var upcomingEvents: [TournamentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        return TournamentCalendar.events(for: selectedTour).filter { $0.endDate >= today }
    }

    private var completedEvents: [TournamentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        return TournamentCalendar.events(for: selectedTour).filter { $0.endDate < today }
    }

    private var heroEvent: TournamentEvent? {
        TournamentCalendar.nextMajor(for: selectedTour)
    }

    var body: some View {
        CourtifyHeroScrollScreen(
            heroHeight: CourtifyLayout.scheduleHeroHeight,
            heroBackground: { heroBackground },
            heroContent: { heroContent },
            listContent: { tournamentListContent }
        )
        .onAppear {
            if let pref = TourPreference(rawValue: tourPreferenceRaw), pref != .both {
                selectedTour = pref == .wta ? .wta : .atp
            }
        }
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Hero

    private var heroBackground: some View {
        LinearGradient(
            colors: [
                ThemeManager.emeraldGreen.opacity(0.9),
                ThemeManager.emeraldGreen.opacity(0.45),
                ThemeManager.midnightGreen,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Upcoming Tournaments")
                    .font(ThemeManager.roundedFont(.title3, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                TourPillToggle(selectedTour: $selectedTour)
            }

            Spacer(minLength: 12)

            if let event = heroEvent {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.tier.rawValue)
                        .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(event.name)
                        .font(ThemeManager.roundedFont(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(event.location)
                        .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                        .foregroundStyle(ThemeManager.opticYellow)

                    Text(event.dateRangeLabel)
                        .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer(minLength: 16)

                if event.startDate > now {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(event.shortName) starts in")
                            .font(ThemeManager.roundedFont(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))

                        HStack(spacing: 20) {
                            countdownUnit(value: TournamentCalendar.countdown(to: event).days, label: "Days")
                            countdownUnit(value: TournamentCalendar.countdown(to: event).hours, label: "Hours")
                            countdownUnit(value: TournamentCalendar.countdown(to: event).minutes, label: "Minutes")
                        }
                    }
                } else {
                    Text("LIVE THIS WEEK")
                        .font(ThemeManager.roundedFont(.caption, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)
                }
            }
        }
        .padding(.bottom, 28)
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(ThemeManager.roundedFont(size: 34, weight: .bold))
                .foregroundStyle(ThemeManager.opticYellow)
            Text(label)
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - List tiles

    @ViewBuilder
    private var tournamentListContent: some View {
        sectionHeader("2026 \(selectedTour.rawValue) calendar · Slams & Masters 1000")
            .padding(.top, 10)

        ForEach(upcomingEvents) { event in
            VStack(spacing: 0) {
                TournamentTile(event: event, isPast: false)
                CourtifyTileDivider()
            }
        }

        if !completedEvents.isEmpty {
            sectionHeader("Completed")
                .padding(.top, 20)

            ForEach(completedEvents) { event in
                VStack(spacing: 0) {
                    TournamentTile(event: event, isPast: true)
                    CourtifyTileDivider()
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ThemeManager.roundedFont(.caption, weight: .semibold))
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

private struct TournamentTile: View {
    let event: TournamentEvent
    let isPast: Bool

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd"
        return formatter.string(from: event.startDate)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: event.startDate)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(dayLabel)
                    .font(ThemeManager.roundedFont(.title3, weight: .bold))
                    .foregroundStyle(isPast ? .white.opacity(0.35) : .white)
                Text(monthLabel)
                    .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(isPast ? 0.25 : 0.55))
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.name)
                        .font(ThemeManager.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(isPast ? .white.opacity(0.4) : .white)

                    if isPast {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ThemeManager.emeraldGreen)
                    }
                }

                Text("\(event.shortName) · \(event.location)")
                    .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(
                        isPast
                            ? Color.white.opacity(0.3)
                            : (event.tier == .grandSlam ? ThemeManager.opticYellow : ThemeManager.courtGreen)
                    )
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(event.surface)
                    .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(isPast ? 0.3 : 0.7))
                Text(event.tier == .grandSlam ? "Slam" : "1000")
                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(isPast ? 0.2 : 0.45))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    ScheduleView()
}
