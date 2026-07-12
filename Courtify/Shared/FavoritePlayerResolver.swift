import Foundation

enum FavoritePlayerResolver {
    static func favoriteSlug() -> String {
        AppGroupConstants.userDefaults.string(forKey: AppGroupConstants.Keys.favoritePlayerID) ?? ""
    }

    static func favoriteDisplayName() -> String? {
        let slug = favoriteSlug()
        guard !slug.isEmpty else { return nil }
        return TennisPlayer.displayName(for: slug)
    }

    static func ranking(for payload: WidgetDataPayload) -> (rank: Int, player: WidgetPlayer)? {
        guard let name = favoriteDisplayName()?.lowercased() else { return nil }

        let entries = payload.rankings.atp + payload.rankings.wta
        if let match = entries.first(where: { $0.player.name.lowercased().contains(name.split(separator: " ").last?.lowercased() ?? name) }) {
            guard let rank = match.rank else { return nil }
            return (rank, match.player)
        }

        if let lastName = name.split(separator: " ").last {
            if let match = entries.first(where: { $0.player.name.lowercased().contains(lastName) }) {
                guard let rank = match.rank else { return nil }
                return (rank, match.player)
            }
        }

        return nil
    }

    static func liveMatch(for payload: WidgetDataPayload) -> WidgetLiveMatch? {
        guard let name = favoriteDisplayName()?.lowercased() else { return nil }
        return payload.liveMatches.first { match in
            match.player1.name.lowercased().contains(name) ||
                match.player2.name.lowercased().contains(name) ||
                nameContains(match.player1.name, favoriteName: name) ||
                nameContains(match.player2.name, favoriteName: name)
        }
    }

    static func nextUpcomingMatch(for payload: WidgetDataPayload) -> WidgetUpcomingMatch? {
        guard let name = favoriteDisplayName()?.lowercased() else { return nil }
        let now = Date()
        return payload.upcomingMatches
            .filter { match in
                guard let start = match.startTime else { return true }
                return start > now
            }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
            .first { match in
                nameContains(match.player1.name, favoriteName: name) ||
                    nameContains(match.player2.name, favoriteName: name)
            }
    }

    static func favoritePlayer(from payload: WidgetDataPayload) -> WidgetPlayer? {
        if let ranking = ranking(for: payload) {
            return ranking.player
        }
        if let live = liveMatch(for: payload) {
            let name = favoriteDisplayName()?.lowercased() ?? ""
            if nameContains(live.player1.name, favoriteName: name) { return live.player1 }
            if nameContains(live.player2.name, favoriteName: name) { return live.player2 }
        }
        return nil
    }

    private static func nameContains(_ playerName: String, favoriteName: String) -> Bool {
        let playerLower = playerName.lowercased()
        let parts = favoriteName.split(separator: " ")
        if let last = parts.last, playerLower.contains(last) { return true }
        return playerLower.contains(favoriteName)
    }
}
