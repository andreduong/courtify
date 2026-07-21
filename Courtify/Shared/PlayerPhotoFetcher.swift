import Foundation

enum PlayerPhotoFetchStatus: Equatable {
    case success
    case skippedBundled
    case notFound
    case quota
    case upstream
    case failed
}

enum PlayerPhotoFetcher {
    struct APIPlayerRef {
        let id: Int
        let tourKey: String
        let name: String
        let atpTourCode: String?
    }

    @discardableResult
    static func ensureHeadPhoto(
        for player: TennisPlayer,
        payload: WidgetDataPayload?,
        apiId: Int? = nil
    ) async -> Bool {
        let status = await ensureHeadPhotoStatus(for: player, payload: payload, apiId: apiId)
        return status == .success || status == .skippedBundled
    }

    static func ensureHeadPhotoStatus(
        for player: TennisPlayer,
        payload: WidgetDataPayload?,
        apiId: Int? = nil
    ) async -> PlayerPhotoFetchStatus {
        if player.imageName != nil {
            return .skippedBundled
        }

        let resolvedPayload = payload ?? WidgetPayloadReader.loadCached()
        guard let ref = apiPlayer(for: player, payload: resolvedPayload, overrideApiId: apiId) else {
            return .notFound
        }

        do {
            try PlayerPhotoStore.ensureDirectory()
        } catch {
            return .failed
        }

        return await downloadStatus(playerID: player.id, ref: ref, variant: .head)
    }

    /// Downloads the studio headshot once. RapidAPI serves the same JPEG for head+hero,
    /// so we never burn a second upstream call or store a fake "hero cutout".
    @discardableResult
    static func ensurePhotos(
        for player: TennisPlayer,
        payload: WidgetDataPayload?,
        apiId: Int? = nil
    ) async -> Bool {
        let status = await ensurePhotosStatus(for: player, payload: payload, apiId: apiId)
        return status == .success || status == .skippedBundled
    }

    static func ensurePhotosStatus(
        for player: TennisPlayer,
        payload: WidgetDataPayload?,
        apiId: Int? = nil
    ) async -> PlayerPhotoFetchStatus {
        if player.imageName != nil {
            return .skippedBundled
        }

        let resolvedPayload = payload ?? WidgetPayloadReader.loadCached()
        guard let ref = apiPlayer(for: player, payload: resolvedPayload, overrideApiId: apiId) else {
            return .notFound
        }

        do {
            try PlayerPhotoStore.ensureDirectory()
        } catch {
            return .failed
        }

        // RapidAPI Photo/{id}.jpg is a small opaque studio plate — never store it as
        // a "hero cutout" (that produced grey rectangles on Home / Settings / widgets).
        // ATP CDN bodyshots are currently Cloudflare-blocked; if they return later,
        // we can reintroduce a CDN-only hero write behind an explicit cutout header.
        return await downloadStatus(playerID: player.id, ref: ref, variant: .head)
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

        // Name-only / code-only — Worker may still resolve via name-slug photo or ATP CDN.
        return APIPlayerRef(id: 0, tourKey: tourKey, name: player.name, atpTourCode: code)
    }

    private static func downloadStatus(
        playerID: String,
        ref: APIPlayerRef,
        variant: PlayerPhotoVariant
    ) async -> PlayerPhotoFetchStatus {
        guard let destination = PlayerPhotoStore.fileURL(playerID: playerID, variant: variant) else {
            return .failed
        }

        if FileManager.default.fileExists(atPath: destination.path),
           PlayerPhotoStore.isValidImageFile(at: destination.path) {
            return .success
        }

        guard let remoteURL = photoURL(ref: ref, variant: variant) else {
            return .notFound
        }
        guard ref.id > 0 || ref.atpTourCode != nil || !ref.name.isEmpty else {
            return .notFound
        }

        do {
            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failed
            }

            switch http.statusCode {
            case 200 ... 299:
                // Empty / non-image bodies mean no usable photo — not a quota miss.
                guard !data.isEmpty, isImageData(data) else { return .notFound }
                try data.write(to: destination, options: .atomic)
                return .success
            case 404, 400, 403:
                // 403: ATP CDN / inactive plates; Worker normally normalizes to 404.
                return .notFound
            case 429, 503:
                return .quota
            default:
                return .upstream
            }
        } catch {
            return .failed
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
