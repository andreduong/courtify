import Foundation

enum PlayerPhotoVariant: String {
    case head
    case hero
}

enum PlayerPhotoStore {
    static func slug(for playerID: String) -> String {
        playerID
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .lowercased()
    }

    static func fileURL(playerID: String, variant: PlayerPhotoVariant) -> URL? {
        AppGroupConstants.playerImagesDirectory?
            .appendingPathComponent("\(slug(for: playerID))-\(variant.rawValue).jpg", isDirectory: false)
    }

    static func cachedPath(playerID: String, variant: PlayerPhotoVariant) -> String? {
        guard let url = fileURL(playerID: playerID, variant: variant),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url.path
    }

    static func hasCachedPhotos(playerID: String) -> Bool {
        isValidImageFile(playerID: playerID, variant: .head)
            || isValidImageFile(playerID: playerID, variant: .hero)
    }

    static func isValidImageFile(playerID: String, variant: PlayerPhotoVariant) -> Bool {
        guard let path = cachedPath(playerID: playerID, variant: variant) else { return false }
        return isValidImageFile(at: path)
    }

    static func isValidImageFile(at path: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]),
              data.count >= 4 else {
            return false
        }
        let bytes = [UInt8](data.prefix(4))
        if bytes[0] == 0xFF && bytes[1] == 0xD8 { return true }
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 { return true }
        return false
    }

    static func clearCachedPhotos(for playerID: String) {
        for variant in [PlayerPhotoVariant.head, .hero] {
            guard let url = fileURL(playerID: playerID, variant: variant),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func clearAllCachedPhotos() {
        guard let directory = AppGroupConstants.playerImagesDirectory else { return }
        try? FileManager.default.removeItem(at: directory)
        try? ensureDirectory()
    }

    static func ensureDirectory() throws {
        guard let directory = AppGroupConstants.playerImagesDirectory else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
