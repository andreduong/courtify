import SwiftUI
import UIKit

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
        .tint(ThemeManager.brandYellow)
        .preferredColorScheme(.dark)
        .courtifySelectionFeedback(selectedTab)
        .onAppear {
            CourtifyTabBarChrome.apply()
            openPaywallFromDeepLinkIfNeeded()
        }
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

// MARK: - Native tab bar chrome

enum CourtifyTabBarChrome {
    /// Edge-to-edge frosted pane — no solid fill so OLED / ambient glow blur underneath.
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        let item = UITabBarItemAppearance()
        let inactive = UIColor.white.withAlphaComponent(0.42)
        let active = UIColor(red: 0xCC / 255, green: 0xFF / 255, blue: 0, alpha: 1)
        [item.normal, item.selected, item.disabled, item.focused].forEach { state in
            state.iconColor = inactive
            state.titleTextAttributes = [
                .foregroundColor: inactive,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            ]
        }
        item.selected.iconColor = active
        item.selected.titleTextAttributes = [
            .foregroundColor: active,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        ]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.tintColor = active
        tabBar.unselectedItemTintColor = inactive
        tabBar.selectionIndicatorImage = UIImage()
    }
}

#Preview {
    HomeView()
}
