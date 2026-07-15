import AppIntents
import Foundation

struct FavoritePlayerEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Player")
    static var defaultQuery = FavoritePlayerEntityQuery()

    let id: String
    let name: String
    let tourRaw: String
    let rank: Int

    var displayRepresentation: DisplayRepresentation {
        let subtitle = rank > 0 ? "\(tourRaw) · No. \(rank)" : tourRaw
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }

    init(snapshot: FavoritePlayerCatalog.PlayerEntitySnapshot) {
        id = snapshot.id
        name = snapshot.name
        tourRaw = snapshot.tourRaw
        rank = snapshot.rank
    }

    init(id: String, name: String, tourRaw: String, rank: Int) {
        self.id = id
        self.name = name
        self.tourRaw = tourRaw
        self.rank = rank
    }
}

struct FavoritePlayerEntityQuery: EntityQuery {
    func entities(for identifiers: [FavoritePlayerEntity.ID]) async throws -> [FavoritePlayerEntity] {
        identifiers.compactMap { id in
            FavoritePlayerCatalog.entitySnapshot(for: id).map(FavoritePlayerEntity.init(snapshot:))
        }
    }

    func suggestedEntities() async throws -> [FavoritePlayerEntity] {
        FavoritePlayerCatalog.entitySnapshots().map(FavoritePlayerEntity.init(snapshot:))
    }

    func entities(matching string: String) async throws -> [FavoritePlayerEntity] {
        FavoritePlayerCatalog.searchEntitySnapshots(matching: string).map(FavoritePlayerEntity.init(snapshot:))
    }
}

struct SelectFavoritePlayerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Favorite Player"
    static var description = IntentDescription("Choose a player for your home-screen widget.")

    @Parameter(title: "Player")
    var player: FavoritePlayerEntity?
}
