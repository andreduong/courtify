import SwiftUI
import UIKit

/// Per-widget accent color + gradient strength (app-group, shared with WidgetKit).
/// Tournament-branded gallery cards stay on surface/slam colors and ignore this store.
struct WidgetColorConfig: Codable, Equatable {
    /// Preset id — see `WidgetColorPreset`. Use `"custom"` with `customAccentHex`.
    var presetID: String
    /// 0 = nearly flat accent, 1 = strong fade into midnight green.
    var gradientLevel: Double
    /// RGB hex when `presetID == WidgetColorConfig.customPresetID`.
    var customAccentHex: UInt?
    /// Surface texture — see `WidgetTexturePreset`. Defaults to aurora (quiet luxury).
    var textureID: String

    static let customPresetID = "custom"
    static let `default` = WidgetColorConfig(
        presetID: WidgetColorPreset.courtify.rawValue,
        gradientLevel: 0.72,
        customAccentHex: nil,
        textureID: WidgetTexturePreset.aurora.rawValue
    )

    var clampedLevel: Double {
        min(1, max(0, gradientLevel))
    }

    var isCustom: Bool {
        presetID == Self.customPresetID
    }

    var resolvedAccent: Color {
        if isCustom, let hex = customAccentHex {
            return Color(hex: hex)
        }
        return (WidgetColorPreset(rawValue: presetID) ?? .courtify).accent
    }

    var resolvedTexture: WidgetTexturePreset {
        WidgetTexturePreset(rawValue: textureID) ?? .aurora
    }

    enum CodingKeys: String, CodingKey {
        case presetID, gradientLevel, customAccentHex, textureID
    }

    init(
        presetID: String,
        gradientLevel: Double,
        customAccentHex: UInt?,
        textureID: String = WidgetTexturePreset.aurora.rawValue
    ) {
        self.presetID = presetID
        self.gradientLevel = gradientLevel
        self.customAccentHex = customAccentHex
        self.textureID = textureID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        presetID = try c.decode(String.self, forKey: .presetID)
        gradientLevel = try c.decode(Double.self, forKey: .gradientLevel)
        customAccentHex = try c.decodeIfPresent(UInt.self, forKey: .customAccentHex)
        textureID = try c.decodeIfPresent(String.self, forKey: .textureID)
            ?? WidgetTexturePreset.aurora.rawValue
    }
}

/// Atmospheric surface treatment — carbon fiber is one option, not the default.
enum WidgetTexturePreset: String, CaseIterable, Identifiable {
    case aurora
    case spotlight
    case carbon
    case mesh
    case velvet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: "Aurora"
        case .spotlight: "Spotlight"
        case .carbon: "Carbon"
        case .mesh: "Mesh"
        case .velvet: "Velvet"
        }
    }

    var subtitle: String {
        switch self {
        case .aurora: "Soft glow"
        case .spotlight: "Stadium light"
        case .carbon: "Fiber hatch"
        case .mesh: "Fine grid"
        case .velvet: "Deep wash"
        }
    }
}

enum WidgetColorPreset: String, CaseIterable, Identifiable {
    case courtify
    case midnight
    case hardcourt
    case clay
    case grass
    case slate
    case berry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .courtify: "Courtify"
        case .midnight: "Midnight"
        case .hardcourt: "Hard court"
        case .clay: "Clay"
        case .grass: "Grass"
        case .slate: "Slate"
        case .berry: "Berry"
        }
    }

    var accentHex: UInt {
        switch self {
        case .courtify: 0x00703C
        case .midnight: 0x0A120D
        case .hardcourt: 0x0C2340
        case .clay: 0xE35205
        case .grass: 0x006633
        case .slate: 0x2A3340
        case .berry: 0x3D1E52
        }
    }

    var accent: Color { Color(hex: accentHex) }
}

enum WidgetColorStyle {
    static let storeKey = AppGroupConstants.Keys.widgetColorStyles

    /// Gallery / WidgetKit ids that keep tournament brand colors (not user-editable).
    static let tournamentBrandedIDs: Set<String> = [
        "next-small", "countdown", "next-large", "calendar",
    ]

    static let customizableIDs: Set<String> = [
        "favorite", "favorite-medium",
        "atp-medium", "atp-large",
        "wta-medium", "wta-large",
        "live", "order",
    ]

    static func isCustomizable(_ widgetID: String) -> Bool {
        customizableIDs.contains(widgetID)
    }

    static func config(for widgetID: String) -> WidgetColorConfig {
        loadMap()[widgetID] ?? .default
    }

    static func set(_ config: WidgetColorConfig, for widgetID: String, reloadTimelines: Bool = true) {
        guard isCustomizable(widgetID) else { return }
        var map = loadMap()
        let stored = WidgetColorConfig(
            presetID: config.presetID,
            gradientLevel: config.clampedLevel,
            customAccentHex: config.isCustom ? config.customAccentHex : nil,
            textureID: config.resolvedTexture.rawValue
        )
        map[widgetID] = stored
        // Keep small + medium favorite cards on the same accent.
        if widgetID == "favorite" {
            map["favorite-medium"] = stored
        } else if widgetID == "favorite-medium" {
            map["favorite"] = stored
        }
        saveMap(map)
        if reloadTimelines {
            WidgetTimelineRefresher.reloadAll()
        }
        NotificationCenter.default.post(name: AppGroupConstants.widgetColorDidChange, object: widgetID)
    }

    static func reset(_ widgetID: String) {
        var map = loadMap()
        map.removeValue(forKey: widgetID)
        saveMap(map)
        WidgetTimelineRefresher.reloadAll()
        NotificationCenter.default.post(name: AppGroupConstants.widgetColorDidChange, object: widgetID)
    }

    /// Accent → midnight gradient using an explicit accent (marquee / previews).
    static func gradient(
        accent: Color,
        gradientLevel: Double = 0.72,
        startPoint: UnitPoint = .top,
        endPoint: UnitPoint = .bottom
    ) -> LinearGradient {
        let level = min(1, max(0, gradientLevel))
        let bottom = WidgetTheme.midnightGreen.opacity(0.35 + (0.65 * level))
        let mid = accent.opacity(1.0 - (0.35 * level))
        return LinearGradient(
            colors: level < 0.15
                ? [accent, accent.opacity(0.92)]
                : [accent, mid, bottom],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    /// Accent → midnight gradient using saved style (or defaults).
    static func gradient(
        for widgetID: String,
        fallbackAccent: Color = WidgetTheme.emeraldGreen,
        startPoint: UnitPoint = .top,
        endPoint: UnitPoint = .bottom
    ) -> LinearGradient {
        let config = config(for: widgetID)
        let top = config.isCustom
            ? (config.customAccentHex.map { Color(hex: $0) } ?? fallbackAccent)
            : (WidgetColorPreset(rawValue: config.presetID)?.accent ?? fallbackAccent)
        return gradient(
            accent: top,
            gradientLevel: config.clampedLevel,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    static func texture(for widgetID: String) -> WidgetTexturePreset {
        config(for: widgetID).resolvedTexture
    }

    private static func loadMap() -> [String: WidgetColorConfig] {
        guard let data = AppGroupConstants.userDefaults.data(forKey: storeKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: WidgetColorConfig].self, from: data)) ?? [:]
    }

    private static func saveMap(_ map: [String: WidgetColorConfig]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        AppGroupConstants.userDefaults.set(data, forKey: storeKey)
    }

    /// Pack sRGB components from a SwiftUI `Color` into a 24-bit hex.
    static func rgbHex(from color: Color) -> UInt {
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return WidgetColorPreset.courtify.accentHex
        }
        let ri = UInt(max(0, min(255, Int((r * 255).rounded()))))
        let gi = UInt(max(0, min(255, Int((g * 255).rounded()))))
        let bi = UInt(max(0, min(255, Int((b * 255).rounded()))))
        return (ri << 16) | (gi << 8) | bi
    }
}
