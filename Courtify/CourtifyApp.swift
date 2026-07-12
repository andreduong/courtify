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

    private var shouldShowHome: Bool {
        if revenueCat.isProUser { return true }
        if referralBypassActive { return true }
        if hasCompletedOnboarding, AppGroupConstants.referralBypassActive { return true }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestHome") { return true }
        if AppGroupConstants.debugProUserEnabled { return true }
        #endif
        return false
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
        .clipped()
        .task {
            await revenueCat.prepareForLaunch()
            await OfferNotificationManager.refreshAuthorizationState()
            if !revenueCat.isProUser, !referralBypassActive {
                #if DEBUG
                if !shouldShowHome {
                    hasCompletedOnboarding = false
                    AppGroupConstants.clearOnboardingPreferences()
                }
                #else
                hasCompletedOnboarding = false
                AppGroupConstants.clearOnboardingPreferences()
                #endif
            }
            isBootstrapped = true
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
