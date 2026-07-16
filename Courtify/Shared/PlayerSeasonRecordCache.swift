import Foundation

/// App-group cache for current-season W/L of custom favorites (Worker `/api/player-season-record`).
enum PlayerSeasonRecordCache {
    struct Entry: Codable {
        let wins: Int
        let losses: Int
        let season: Int
        let fetchedAt: Date
    }

    private static let mapKey = "playerSeasonRecordCache"
    /// Local freshness window — Worker KV is 24h; re-fetch sooner only on pick/enrich.
    private static let maxAge: TimeInterval = 60 * 60 * 24

    static func record(for playerID: String) -> (wins: Int, losses: Int)? {
        guard let entry = entry(for: playerID) else { return nil }
        return (entry.wins, entry.losses)
    }

    static func entry(for playerID: String) -> Entry? {
        loadMap()[playerID]
    }

    static func isFresh(for playerID: String) -> Bool {
        guard let entry = entry(for: playerID) else { return false }
        return Date().timeIntervalSince(entry.fetchedAt) < maxAge
    }

    static func store(wins: Int, losses: Int, season: Int, for playerID: String) {
        guard wins >= 0, losses >= 0 else { return }
        var map = loadMap()
        map[playerID] = Entry(wins: wins, losses: losses, season: season, fetchedAt: Date())
        saveMap(map)
    }

    static func remove(for playerID: String) {
        var map = loadMap()
        map.removeValue(forKey: playerID)
        saveMap(map)
    }

    static func clearAll() {
        AppGroupConstants.userDefaults.removeObject(forKey: mapKey)
    }

    private static func loadMap() -> [String: Entry] {
        guard let data = AppGroupConstants.userDefaults.data(forKey: mapKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private static func saveMap(_ map: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        AppGroupConstants.userDefaults.set(data, forKey: mapKey)
    }
}
