import Foundation

enum PlayerPhotoFetcher {
    struct APIPlayerRef {
        let id: Int
        let tourKey: String
        let name: String
        let atpTourCode: String?
    }

    @discardableResult
    static func ensurePhotos(
        for player: TennisPlayer,
        payload: WidgetDataPayload?,
        apiId: Int? = nil
    ) async -> Bool {
        if player.imageName != nil {
            return true
        }

        let resolvedPayload = payload ?? WidgetPayloadReader.loadCached()
        var ref = apiPlayer(for: player, payload: resolvedPayload, overrideApiId: apiId)
        guard let ref else {
            return false
        }

        do {
            try PlayerPhotoStore.ensureDirectory()
        } catch {
            return false
        }

        async let head = download(playerID: player.id, ref: ref, variant: .head)
        async let hero = download(playerID: player.id, ref: ref, variant: .hero)
        let results = await [head, hero]
        return results.contains(true)
    }

    static func apiPlayer(
        for player: TennisPlayer,
        payload: WidgetDataPayload?,
        overrideApiId: Int? = nil
    ) -> APIPlayerRef? {
        let tourKey = player.tour == .wta ? "wta" : "atp"

        if let overrideApiId, overrideApiId > 0 {
            let code = PlayerSearchCatalog.atpTourCode(for: player.name)
            return APIPlayerRef(id: overrideApiId, tourKey: tourKey, name: player.name, atpTourCode: code)
        }

        if let cachedApiId = PlayerRankCache.apiId(for: player.id), cachedApiId > 0 {
            let code = PlayerSearchCatalog.atpTourCode(for: player.name)
            return APIPlayerRef(id: cachedApiId, tourKey: tourKey, name: player.name, atpTourCode: code)
        }

        if let match = FavoritePlayerCatalog.payloadRankingEntry(for: player, payload: payload),
           let id = match.player.id {
            let code = PlayerSearchCatalog.atpTourCode(for: player.name)
            return APIPlayerRef(id: id, tourKey: tourKey, name: player.name, atpTourCode: code)
        }

        let code = PlayerSearchCatalog.atpTourCode(for: player.name)
        if let bundledId = PlayerSearchCatalog.bundledApiId(for: player.name, tour: player.tour), bundledId > 0 {
            return APIPlayerRef(id: bundledId, tourKey: tourKey, name: player.name, atpTourCode: code)
        }

        return APIPlayerRef(id: 0, tourKey: tourKey, name: player.name, atpTourCode: code)
    }

    private static func download(
        playerID: String,
        ref: APIPlayerRef,
        variant: PlayerPhotoVariant
    ) async -> Bool {
        guard let destination = PlayerPhotoStore.fileURL(playerID: playerID, variant: variant) else {
            return false
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            return true
        }

        guard let remoteURL = photoURL(ref: ref, variant: variant) else {
            return false
        }
        guard ref.id > 0 || (ref.tourKey == "atp" && ref.atpTourCode != nil) else {
            return false
        }

        do {
            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode),
                  !data.isEmpty, isImageData(data) else {
                return false
            }
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func isImageData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let bytes = [UInt8](data.prefix(4))
        if bytes[0] == 0xFF && bytes[1] == 0xD8 { return true }
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 { return true }
        return false
    }

    private static func photoURL(ref: APIPlayerRef, variant: PlayerPhotoVariant) -> URL? {
        var components = URLComponents(string: WidgetAPIService.playerPhotoURL.absoluteString)
        var queryItems = [
            URLQueryItem(name: "tour", value: ref.tourKey),
            URLQueryItem(name: "variant", value: variant.rawValue),
            URLQueryItem(name: "name", value: ref.name),
        ]
        if ref.id > 0 {
            queryItems.append(URLQueryItem(name: "apiId", value: String(ref.id)))
        }
        if let code = ref.atpTourCode, !code.isEmpty {
            queryItems.append(URLQueryItem(name: "code", value: code))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}
