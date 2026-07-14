import SwiftUI

enum HomeTab: String, CaseIterable, Identifiable {
    case home
    case schedule
    case rankings
    case widgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .schedule: "Schedule"
        case .rankings: "Rankings"
        case .widgets: "Widgets"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .schedule: "calendar"
        case .rankings: "trophy"
        case .widgets: "square.grid.2x2"
        }
    }
}

struct HomeView: View {
    @State private var selectedTab: HomeTab = HomeView.initialTab

    /// DEBUG-only: launch with `-UITestTab schedule|rankings|widgets` to open a
    /// specific tab in the simulator (used by agents to screenshot tabs).
    private static var initialTab: HomeTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "UITestTab"),
           let tab = HomeTab(rawValue: raw) {
            return tab
        }
        #endif
        return .home
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView()
                .tabItem {
                    Label(HomeTab.home.title, systemImage: HomeTab.home.icon)
                }
                .tag(HomeTab.home)

            ScheduleView()
                .tabItem {
                    Label(HomeTab.schedule.title, systemImage: HomeTab.schedule.icon)
                }
                .tag(HomeTab.schedule)

            RankingsView()
                .tabItem {
                    Label(HomeTab.rankings.title, systemImage: HomeTab.rankings.icon)
                }
                .tag(HomeTab.rankings)

            WidgetsCollectionView()
                .tabItem {
                    Label(HomeTab.widgets.title, systemImage: HomeTab.widgets.icon)
                }
                .tag(HomeTab.widgets)
        }
        .tint(ThemeManager.opticYellow)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HomeView()
}
