import UIKit

enum WidgetImageCache {
    private static let maxPixelDimension: CGFloat = 320
    private static let jpegQuality: CGFloat = 0.65
    private static let maxConcurrentDownloads = 4

    @discardableResult
    static func cachedImagePath(forPlayerID playerID: Int, remoteURL: URL) async -> String? {
        guard let destination = localFileURL(playerID: playerID) else { return nil }

        if FileManager.default.fileExists(atPath: destination.path),
           let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
           let size = attributes[.size] as? Int, size > 0 {
            return destination.path
        }

        do {
            try ensureImagesDirectoryExists()
            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }

            guard let resized = resizeImageData(data) else { return nil }
            try resized.write(to: destination, options: .atomic)
            return destination.path
        } catch {
            return nil
        }
    }

    static func cacheImages(for players: [WidgetPlayer]) async -> [Int: String] {
        var paths: [Int: String] = [:]
        let uniquePlayers = Dictionary(
            players.compactMap { player -> (Int, WidgetPlayer)? in
                guard let id = player.id else { return nil }
                return (id, player)
            },
            uniquingKeysWith: { first, _ in first }
        )

        await withTaskGroup(of: (Int, String?).self) { group in
            var active = 0
            var iterator = uniquePlayers.makeIterator()

            func enqueueNext() {
                while active < maxConcurrentDownloads, let (id, player) = iterator.next() {
                    guard let url = player.imageURL else { continue }
                    active += 1
                    group.addTask {
                        let path = await cachedImagePath(forPlayerID: id, remoteURL: url)
                        return (id, path)
                    }
                }
            }

            enqueueNext()

            for await (id, path) in group {
                active -= 1
                if let path { paths[id] = path }
                enqueueNext()
            }
        }

        return paths
    }

    private static func localFileURL(playerID: Int) -> URL? {
        AppGroupConstants.playerImagesDirectory?
            .appendingPathComponent("\(playerID).jpg", isDirectory: false)
    }

    private static func ensureImagesDirectoryExists() throws {
        guard let directory = AppGroupConstants.playerImagesDirectory else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func resizeImageData(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longest = max(width, height)

        guard longest > maxPixelDimension else {
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: jpegQuality)
        }

        let scale = maxPixelDimension / longest
        let targetSize = CGSize(width: width * scale, height: height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.jpegData(compressionQuality: jpegQuality)
    }
}
