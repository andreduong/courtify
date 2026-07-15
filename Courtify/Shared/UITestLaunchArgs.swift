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

    static var showsSettings: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestSettings")
    }

    /// `schedule`, `rankings`, or `widgets` (not `home` — omit flag for Home tab).
    static var tab: String? {
        value(after: "-UITestTab")
    }

    /// `free`, `small`, `medium`, or `large` (case-insensitive).
    static var widgetFilter: String? {
        value(after: "-UITestWidgetFilter")
    }

    /// Item id from the `sections` catalog in `WidgetsCollectionView.swift`.
    static var widgetOnlyItemID: String? {
        value(after: "-UITestWidgetOnly")
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
