import Foundation

@MainActor
final class WidgetDataStore: ObservableObject {
    static let shared = WidgetDataStore()

    @Published private(set) var payload: WidgetDataPayload?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var loadTask: Task<Void, Never>?

    func refreshIfNeeded() {
        guard loadTask == nil else { return }
        loadTask = Task {
            await refresh()
            loadTask = nil
        }
    }

    func refresh() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            payload = try await WidgetAPIService.fetchWidgetData()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func rankings(for tour: TourPreference) -> [WidgetRankingEntry] {
        guard let payload else { return fallbackRankings(for: tour) }
        switch tour {
        case .atp: return payload.rankings.atp
        case .wta: return payload.rankings.wta.isEmpty ? fallbackRankings(for: tour) : payload.rankings.wta
        case .both: return payload.rankings.atp
        }
    }

    private func fallbackRankings(for tour: TourPreference) -> [WidgetRankingEntry] {
        TennisPlayer.topPlayers
            .filter { $0.tour == tour }
            .prefix(10)
            .map { player in
                WidgetRankingEntry(
                    rank: player.ranking,
                    points: nil,
                    player: WidgetPlayer(id: nil, name: player.name, country: nil, imageUrl: nil)
                )
            }
    }
}
