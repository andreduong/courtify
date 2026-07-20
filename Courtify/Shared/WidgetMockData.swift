import Foundation

enum WidgetMockData {
    static var sample: WidgetDataPayload {
        try! JSONDecoder().decode(
            WidgetDataPayload.self,
            from: Data(sampleJSON.utf8)
        )
    }

    static let sampleJSON = """
    {
      "updatedAt": "2026-07-10T19:00:00Z",
      "liveMatches": [
        {
          "id": 101,
          "tour": "ATP",
          "tournament": "Wimbledon",
          "court": "Centre Court",
          "status": "LIVE",
          "score": "6-4 3-6 4-4",
          "gameScore": "40-30",
          "server": 1,
          "player1": { "id": 5993, "name": "Carlos Alcaraz", "country": "ESP", "imageUrl": null },
          "player2": { "id": 5992, "name": "Jannik Sinner", "country": "ITA", "imageUrl": null }
        }
      ],
      "upcomingMatches": [
        {
          "id": 102,
          "tour": "ATP",
          "tournament": "Australian Open",
          "court": "Rod Laver Arena",
          "round": "QF",
          "startTime": "2026-01-22T02:00:00Z",
          "player1": { "id": 5992, "name": "Jannik Sinner", "country": "ITA", "imageUrl": null },
          "player2": { "id": 5993, "name": "Carlos Alcaraz", "country": "ESP", "imageUrl": null }
        },
        {
          "id": 103,
          "tour": "WTA",
          "tournament": "Australian Open",
          "court": "Rod Laver Arena",
          "round": "QF",
          "startTime": "2026-01-22T04:00:00Z",
          "player1": { "id": 7002, "name": "Aryna Sabalenka", "country": "BLR", "imageUrl": null },
          "player2": { "id": 7001, "name": "Iga Świątek", "country": "POL", "imageUrl": null }
        }
      ],
      "rankings": {
        "atp": [
          { "rank": 1, "points": 12000, "player": { "id": 5992, "name": "Jannik Sinner", "country": "ITA", "imageUrl": null } },
          { "rank": 2, "points": 11000, "player": { "id": 5993, "name": "Carlos Alcaraz", "country": "ESP", "imageUrl": null } },
          { "rank": 3, "points": 10000, "player": { "id": 5994, "name": "Novak Djokovic", "country": "SRB", "imageUrl": null } },
          { "rank": 4, "points": 9000, "player": { "id": 5995, "name": "Daniil Medvedev", "country": "RUS", "imageUrl": null } },
          { "rank": 5, "points": 8000, "player": { "id": 5996, "name": "Alexander Zverev", "country": "GER", "imageUrl": null } },
          { "rank": 6, "points": 7000, "player": { "id": 5997, "name": "Taylor Fritz", "country": "USA", "imageUrl": null } },
          { "rank": 7, "points": 6000, "player": { "id": 5998, "name": "Ben Shelton", "country": "USA", "imageUrl": null } },
          { "rank": 8, "points": 5000, "player": { "id": 5999, "name": "Tommy Paul", "country": "USA", "imageUrl": null } },
          { "rank": 9, "points": 4000, "player": { "id": 6000, "name": "Hubert Hurkacz", "country": "POL", "imageUrl": null } },
          { "rank": 10, "points": 3000, "player": { "id": 6001, "name": "Casper Ruud", "country": "NOR", "imageUrl": null } }
        ],
        "wta": [
          { "rank": 1, "points": 9800, "player": { "id": 7001, "name": "Iga Świątek", "country": "POL", "imageUrl": null } },
          { "rank": 2, "points": 8700, "player": { "id": 7002, "name": "Aryna Sabalenka", "country": "BLR", "imageUrl": null } },
          { "rank": 3, "points": 7600, "player": { "id": 7003, "name": "Coco Gauff", "country": "USA", "imageUrl": null } },
          { "rank": 4, "points": 6500, "player": { "id": 7004, "name": "Elena Rybakina", "country": "KAZ", "imageUrl": null } },
          { "rank": 5, "points": 5400, "player": { "id": 7005, "name": "Jessica Pegula", "country": "USA", "imageUrl": null } },
          { "rank": 6, "points": 4300, "player": { "id": 7006, "name": "Jasmine Paolini", "country": "ITA", "imageUrl": null } },
          { "rank": 7, "points": 3200, "player": { "id": 7007, "name": "Madison Keys", "country": "USA", "imageUrl": null } },
          { "rank": 8, "points": 2100, "player": { "id": 7008, "name": "Zheng Qinwen", "country": "CHN", "imageUrl": null } },
          { "rank": 9, "points": 1800, "player": { "id": 7009, "name": "Barbora Krejcikova", "country": "CZE", "imageUrl": null } },
          { "rank": 10, "points": 1500, "player": { "id": 7010, "name": "Mirra Andreeva", "country": "RUS", "imageUrl": null } }
        ],
      },
      "meta": { "sources": { "live": "mock", "atpRankings": "mock", "wtaRankings": "mock" } }
    }
    """
}
