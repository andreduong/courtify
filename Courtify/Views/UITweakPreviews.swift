import SwiftUI

// MARK: - UI tweak hub
//
// Open this file in Xcode and enable Canvas (⌥⌘↩). Pick a preview from the
// selector at the bottom. Saves refresh the canvas instantly — no simulator
// build. Uses bundled/mock data only (no Worker, app group, or RevenueCat).

#Preview("Rankings") {
    RankingsView()
        .preferredColorScheme(.dark)
}

#Preview("Schedule") {
    ScheduleView()
        .preferredColorScheme(.dark)
}

#Preview("Widgets gallery") {
    WidgetsCollectionView()
        .preferredColorScheme(.dark)
}

#Preview("Home dashboard") {
    HomeDashboardView()
        .preferredColorScheme(.dark)
}

#Preview("Settings") {
    SettingsView()
        .preferredColorScheme(.dark)
}
