import WidgetKit
import SwiftUI

@main
struct CourtifyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlayerTrackerWidget()
        OrderOfPlayWidget()
    }
}
