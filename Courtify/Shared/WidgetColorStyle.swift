import SwiftUI

/// Per-widget accent color + gradient strength (app-group, shared with WidgetKit).
/// Tournament-branded gallery cards stay on surface/slam colors and ignore this store.
struct WidgetColorConfig: Codable, Equatable {
    /// Preset id — see `WidgetColorPreset`.
    var presetID: String
    /// 0 = nearly flat accent, 1 = strong fade into midnight green.
    var gradientLevel: Double

    static let `default` = WidgetColorConfig(presetID: WidgetColorPreset.courtify.rawValue, gradientLevel: 0.85)

    var clampedLevel: Double {
        min(1, max(0, gradientLevel))
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
        "favorite",
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

    static func set(_ config: WidgetColorConfig, for widgetID: String) {
        guard isCustomizable(widgetID) else { return }
        var map = loadMap()
        map[widgetID] = WidgetColorConfig(
            presetID: config.presetID,
            gradientLevel: config.clampedLevel
        )
        saveMap(map)
        WidgetTimelineRefresher.reloadAll()
        NotificationCenter.default.post(name: AppGroupConstants.widgetColorDidChange, object: widgetID)
    }

    static func reset(_ widgetID: String) {
        var map = loadMap()
        map.removeValue(forKey: widgetID)
        saveMap(map)
        WidgetTimelineRefresher.reloadAll()
        NotificationCenter.default.post(name: AppGroupConstants.widgetColorDidChange, object: widgetID)
    }

    /// Accent → midnight gradient using saved style (or defaults).
    static func gradient(
        for widgetID: String,
        fallbackAccent: Color = WidgetTheme.emeraldGreen,
        startPoint: UnitPoint = .top,
        endPoint: UnitPoint = .bottom
    ) -> LinearGradient {
        let config = config(for: widgetID)
        let preset = WidgetColorPreset(rawValue: config.presetID)
        let top = preset?.accent ?? fallbackAccent
        let level = config.clampedLevel
        // Higher level → more midnight at the bottom; low level → flatter accent wash.
        let bottom = WidgetTheme.midnightGreen.opacity(0.35 + (0.65 * level))
        let mid = top.opacity(1.0 - (0.35 * level))
        return LinearGradient(
            colors: level < 0.15
                ? [top, top.opacity(0.92)]
                : [top, mid, bottom],
            startPoint: startPoint,
            endPoint: endPoint
        )
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
}
