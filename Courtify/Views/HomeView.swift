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
    @StateObject private var revenueCat = RevenueCatManager.shared
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.appGroupStorage)
    private var favoritePlayerID = ""
    @State private var selectedTab: HomeTab = HomeView.initialTab
    @State private var showPaywallFromDeepLink = false

    /// DEBUG-only: launch with `-UITestTab schedule|rankings|widgets` to open a
    /// specific tab in the simulator (used by agents to screenshot tabs).
    private static var initialTab: HomeTab {
        #if DEBUG
        if let raw = UITestLaunchArgs.tab, let tab = HomeTab(rawValue: raw) {
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
        .onAppear(perform: openPaywallFromDeepLinkIfNeeded)
        .onReceive(NotificationCenter.default.publisher(for: .courtifyOpenPaywall)) { _ in
            openPaywallFromDeepLinkIfNeeded()
        }
        .sheet(isPresented: $showPaywallFromDeepLink) {
            PaywallView(
                favoritePlayerID: favoritePlayerID.isEmpty ? "sinner" : favoritePlayerID,
                managesOwnCloseButton: true,
                onSubscribed: { showPaywallFromDeepLink = false },
                onClose: { showPaywallFromDeepLink = false },
                onSkip: { showPaywallFromDeepLink = false }
            )
        }
    }

    private func openPaywallFromDeepLinkIfNeeded() {
        guard PaywallDeepLink.shouldOpenPaywall else { return }
        PaywallDeepLink.shouldOpenPaywall = false
        guard !revenueCat.isProUser, !AppGroupConstants.referralBypassActive else { return }
        showPaywallFromDeepLink = true
    }
}

#Preview {
    HomeView()
}
