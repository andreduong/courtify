import SwiftUI
import WidgetKit

/// Home-screen locked Premium state — delegates to shared `WidgetLockedSurface`.
struct WidgetLockedView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetLockedSurface(layout: WidgetLockedLayout.from(family: family))
            .courtifyWidgetCanvas(stamp: WidgetStampPlacement.none)
            .widgetURL(CourtifyDeepLinks.paywallURL)
    }
}
