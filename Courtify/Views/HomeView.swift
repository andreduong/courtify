import SwiftUI

enum HomeTab: String, CaseIterable, Identifiable {
    case schedule
    case rankings
    case widgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "Schedule"
        case .rankings: "Rankings"
        case .widgets: "Widgets"
        }
    }

    var icon: String {
        switch self {
        case .schedule: "calendar"
        case .rankings: "trophy"
        case .widgets: "square.grid.2x2"
        }
    }
}

struct HomeView: View {
    @State private var selectedTab: HomeTab = .schedule

    var body: some View {
        TabView(selection: $selectedTab) {
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
