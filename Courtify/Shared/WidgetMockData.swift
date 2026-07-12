import Foundation

enum WidgetMockData {
    static var sample: WidgetDataPayload {
        try! JSONDecoder().decode(
            WidgetDataPayload.self,
            from: Data(sampleJSON.utf8)
        )
    }

    private static let sampleJSON = """
    {
      "updatedAt": "2026-07-10T19:00:00Z",
      "liveMatches": [
        {
          "id": 101,
          "tour": "ATP",
          "tournament": "Wimbledon",
          "court": "Centre Court",
          "status": "LIVE",
          "score": "6-4 4-4",
          "gameScore": "30-15",
          "server": 2,
          "player1": { "id": 5993, "name": "Carlos Alcaraz", "country": "ESP", "imageUrl": null },
          "player2": { "id": 5992, "name": "Jannik Sinner", "country": "ITA", "imageUrl": null }
        }
      ],
      "upcomingMatches": [
        {
          "id": 102,
          "tour": "ATP",
          "tournament": "Wimbledon",
          "court": "Centre Court",
          "round": "SF",
          "startTime": "2026-07-10T23:00:00Z",
          "player1": { "id": 5994, "name": "Novak Djokovic", "country": "SRB", "imageUrl": null },
          "player2": { "id": 5992, "name": "Jannik Sinner", "country": "ITA", "imageUrl": null }
        }
      ],
      "rankings": {
        "atp": [
          { "rank": 1, "points": 12000, "player": { "id": 5994, "name": "Novak Djokovic", "country": "SRB", "imageUrl": null } },
          { "rank": 2, "points": 11000, "player": { "id": 5992, "name": "Jannik Sinner", "country": "ITA", "imageUrl": null } },
          { "rank": 3, "points": 10000, "player": { "id": 5993, "name": "Carlos Alcaraz", "country": "ESP", "imageUrl": null } }
        ],
        "wta": []
      },
      "meta": { "sources": { "live": "mock", "atpRankings": "mock", "wtaRankings": "mock" } }
    }
    """
}
