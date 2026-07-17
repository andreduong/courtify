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

    static let customPresetID = "custom"
    static let `default` = WidgetColorConfig(
        presetID: WidgetColorPreset.courtify.rawValue,
        gradientLevel: 0.85,
        customAccentHex: nil
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
            customAccentHex: config.isCustom ? config.customAccentHex : nil
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
