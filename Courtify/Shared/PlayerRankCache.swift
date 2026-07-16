import Foundation

/// App-group cache for ranks (and optional API ids) of players outside the top-20 widget payload.
enum PlayerRankCache {
    struct Entry: Codable {
        let rank: Int
        let apiId: Int?
        let name: String?
        var photosVerified: Bool
    }

    private static let mapKey = "playerRankCache"

    static func rank(for playerID: String) -> Int? {
        guard let entry = entry(for: playerID), entry.rank > 0 else { return nil }
        return entry.rank
    }

    static func apiId(for playerID: String) -> Int? {
        entry(for: playerID)?.apiId
    }

    static func photosVerified(for playerID: String) -> Bool {
        entry(for: playerID)?.photosVerified == true
    }

    static func entry(for playerID: String) -> Entry? {
        loadMap()[playerID]
    }

    static func store(
        rank: Int,
        apiId: Int?,
        name: String?,
        photosVerified: Bool,
        for playerID: String
    ) {
        guard rank > 0 || (apiId != nil && apiId! > 0) else { return }
        var map = loadMap()
        map[playerID] = Entry(rank: rank, apiId: apiId, name: name, photosVerified: photosVerified)
        saveMap(map)
    }

    static func markPhotosVerified(for playerID: String) {
        guard var entry = entry(for: playerID) else { return }
        entry.photosVerified = true
        var map = loadMap()
        map[playerID] = entry
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
