import Foundation

#if DEBUG
/// Parses `simctl launch … -UITestHome -UITestTab schedule` style flags from
/// `ProcessInfo.processInfo.arguments`. All agent screenshot hooks use this —
/// do not read `UserDefaults` for launch args.
enum UITestLaunchArgs {
    static var showsHome: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestHome")
    }

    static var resetsForPaywall: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestPaywall")
    }

    /// Opens a specific onboarding step (skips splash). Values: `tour`, `players`, `slam`.
    /// Example: `-UITestOnboarding players`
    static var onboardingStep: String? {
        value(after: "-UITestOnboarding")?.lowercased()
    }

    static var showsSettings: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestSettings")
    }

    /// `schedule`, `rankings`, or `widgets` (not `home` — omit flag for Home tab).
    static var tab: String? {
        value(after: "-UITestTab")
    }

    /// `free`, `small`, `medium`, `large`, or `lockscreen` (case-insensitive).
    static var widgetFilter: String? {
        value(after: "-UITestWidgetFilter")
    }

    /// Item id from the `sections` catalog in `WidgetsCollectionView.swift`.
    static var widgetOnlyItemID: String? {
        value(after: "-UITestWidgetOnly")
    }

    /// Opens the favorite-player picker sheet (Widgets tab).
    static var opensFavoritePicker: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestFavoritePicker")
    }

    /// Opens the widget color sheet for a customizable gallery id (default `favorite`).
    /// Example: `-UITestWidgetColor` or `-UITestWidgetColor live`
    static var widgetColorItemID: String? {
        if let value = value(after: "-UITestWidgetColor") {
            return value
        }
        if ProcessInfo.processInfo.arguments.contains("-UITestWidgetColor") {
            return "favorite"
        }
        return nil
    }

    /// Opens the widget share screen for a gallery id (default `favorite`).
    /// Example: `-UITestWidgetShare` or `-UITestWidgetShare live`
    static var widgetShareItemID: String? {
        if let value = value(after: "-UITestWidgetShare") {
            return value
        }
        if ProcessInfo.processInfo.arguments.contains("-UITestWidgetShare") {
            return "favorite"
        }
        return nil
    }

    static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        let value = args[index + 1]
        guard !value.hasPrefix("-") else { return nil }
        return value
    }
}
#endif
