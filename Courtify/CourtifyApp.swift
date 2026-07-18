import SwiftUI

@main
struct CourtifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppGroupConstants.Keys.referralBypassActive, store: AppGroupConstants.appGroupStorage)
    private var referralBypassActive = false
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var isBootstrapped = false

    /// Home requires finished onboarding — not bare Pro/referral.
    /// Otherwise purchase/bypass can flip `shouldShowHome` before drafts are committed,
    /// dropping favorite player / Grand Slam picks from a fresh install.
    private var shouldShowHome: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestPaywall") { return false }
        if ProcessInfo.processInfo.arguments.contains("-UITestHome") { return true }
        if AppGroupConstants.debugProUserEnabled, hasCompletedOnboarding { return true }
        #endif
        return hasCompletedOnboarding
    }

    var body: some View {
        ZStack {
            if !isBootstrapped {
                bootstrapView
                    .transition(CourtifyMotion.crossfade)
                    .zIndex(0)
            } else if shouldShowHome {
                HomeView()
                    .transition(CourtifyMotion.screenTransition(.forward))
                    .zIndex(1)
            } else {
                OnboardingFlowView()
                    .transition(CourtifyMotion.crossfade)
                    .zIndex(1)
            }
        }
        .animation(CourtifyMotion.screen, value: isBootstrapped)
        .animation(CourtifyMotion.screen, value: shouldShowHome)
        .background(ThemeManager.midnightGreen.ignoresSafeArea())
        // Default press scale + soft haptic for every Button in the hierarchy.
        // Explicit `.courtifyButton(.primary/.card/.icon/…)` still overrides per control.
        .courtifyInteractiveChrome()
        .task {
            AppGroupConstants.migratePlayerCachesIfNeeded()
            await revenueCat.prepareForLaunch()
            await OfferNotificationManager.refreshAuthorizationState()
            BundledImageCache.warmOnboardingAssets()
            AppGroupConstants.syncWidgetAccess(
                isProUser: revenueCat.isProUser,
                referralBypass: referralBypassActive
            )
            if ProcessInfo.processInfo.arguments.contains("-UITestPaywall") {
                hasCompletedOnboarding = false
                AppGroupConstants.clearOnboardingPreferences()
            }
            // Returning Pro users still need onboarding once per install to pick favorites.
            // Do not set hasCompletedOnboarding from entitlement alone.
            isBootstrapped = true
        }
        .onOpenURL { url in
            guard CourtifyDeepLinks.isPaywall(url) else { return }
            PaywallDeepLink.shouldOpenPaywall = true
            NotificationCenter.default.post(name: .courtifyOpenPaywall, object: nil)
        }
    }

    private var bootstrapView: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()
            ProgressView()
                .tint(ThemeManager.opticYellow)
        }
    }
}
