import WidgetKit

enum WidgetTimelineRefresher {
    static let playerTrackerKind = "PlayerTrackerWidget"
    static let orderOfPlayKind = "OrderOfPlayWidget"

    static func reloadAll() {
        WidgetCenter.shared.reloadTimelines(ofKind: playerTrackerKind)
        WidgetCenter.shared.reloadTimelines(ofKind: orderOfPlayKind)
    }
}
