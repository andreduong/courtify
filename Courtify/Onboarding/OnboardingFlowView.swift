import SwiftUI

enum OnboardingStep: Hashable {
    case splash
    case tourPreference
    case favoritePlayers
    case favoriteGrandSlam
    case notifications
    case referralCode
    case paywall
}

struct OnboardingFlowView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var path: [OnboardingStep] = []
    @State private var navigationDirection: CourtifyMotion.Direction = .forward
    @State private var draftTourPreference: TourPreference = .both
    @State private var draftFavoritePlayerID = ""
    @State private var draftFavoriteGrandSlam = ""
    @State private var showSpecialOfferOnPaywall = false

    private var onboardingProgress: Double {
        OnboardingProgress.progress(for: path)
    }

    private var showsBackButton: Bool {
        !path.isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            CourtifyScreenFlow(path: $path, direction: $navigationDirection) {
                SplashScreenView {
                    navigateForward(.tourPreference)
                }
            } destination: { step in
                destinationView(for: step)
            }

            OnboardingChrome(
                progress: onboardingProgress,
                showsBackButton: showsBackButton,
                onBack: navigateBackward
            )
        }
        .courtifyBackground()
        .ignoresSafeArea()
        .onAppear {
            openSpecialOfferPaywallIfNeeded()
            openPaywallIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .courtifyOpenSpecialOfferPaywall)) { _ in
            openSpecialOfferPaywallIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .courtifyOpenPaywall)) { _ in
            openPaywallIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            OnboardingReminderManager.cancelAbandonmentReminders()
        case .background:
            guard path.last == .paywall,
                  !revenueCat.isProUser,
                  !AppGroupConstants.referralBypassActive else { return }
            OnboardingReminderManager.scheduleAbandonmentRemindersIfNeeded()
        default:
            break
        }
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .splash:
            EmptyView()
        case .tourPreference:
            TourPreferenceView(tourPreference: $draftTourPreference) {
                navigateForward(.favoritePlayers)
            }
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .favoritePlayers:
            FavoritePlayersView(
                tourPreference: draftTourPreference,
                favoritePlayerID: $draftFavoritePlayerID
            ) {
                navigateForward(.favoriteGrandSlam)
            }
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .favoriteGrandSlam:
            FavoriteGrandSlamView(favoriteGrandSlam: $draftFavoriteGrandSlam) {
                navigateForward(.notifications)
            }
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .notifications:
            NotificationPermissionView(
                favoritePlayerID: draftFavoritePlayerID,
                favoriteGrandSlam: draftFavoriteGrandSlam,
                onContinue: { navigateForward(.referralCode) }
            )
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .referralCode:
            ReferralCodeView(
                onSubmit: completeOnboardingViaReferral,
                onSkip: { navigateForward(.paywall) }
            )
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .paywall:
            PaywallView(
                favoritePlayerID: draftFavoritePlayerID,
                showSpecialOfferOnAppear: showSpecialOfferOnPaywall,
                onSubscribed: completeOnboarding,
                onClose: returnToJoinScreen,
                onSkip: completeOnboardingAsFreeUser
            )
        }
    }

    private var onboardingContentTopInset: CGFloat {
        showsBackButton ? 52 : 18
    }

    private func navigateForward(_ step: OnboardingStep) {
        CourtifyMotion.animateScreen(.forward) {
            navigationDirection = .forward
            path.append(step)
        }
    }

    private func navigateBackward() {
        CourtifyMotion.animateScreen(.backward) {
            navigationDirection = .backward
            if path.isEmpty {
                return
            }
            path.removeLast()
        }
    }

    private func openPaywallIfNeeded() {
        guard PaywallDeepLink.shouldOpenPaywall,
              !revenueCat.isProUser,
              !AppGroupConstants.referralBypassActive else { return }
        PaywallDeepLink.shouldOpenPaywall = false

        if path.last != .paywall {
            CourtifyMotion.animateScreen(.forward) {
                navigationDirection = .forward
                if path.isEmpty {
                    path = [.tourPreference, .favoritePlayers, .favoriteGrandSlam, .notifications, .referralCode, .paywall]
                } else if !path.contains(.paywall) {
                    path.append(.paywall)
                } else {
                    path = path.filter { $0 != .paywall } + [.paywall]
                }
            }
        }
    }

    private func openSpecialOfferPaywallIfNeeded() {
        guard PaywallDeepLink.shouldShowSpecialOffer,
              !revenueCat.isProUser,
              !AppGroupConstants.referralBypassActive else { return }
        showSpecialOfferOnPaywall = true
        PaywallDeepLink.shouldShowSpecialOffer = false

        if path.last != .paywall {
            CourtifyMotion.animateScreen(.forward) {
                navigationDirection = .forward
                if path.isEmpty {
                    path = [.tourPreference, .favoritePlayers, .favoriteGrandSlam, .notifications, .referralCode, .paywall]
                } else {
                    path.append(.paywall)
                }
            }
        }
    }

    private func completeOnboarding() {
        guard revenueCat.isProUser else { return }
        commitOnboardingAndFinish(grantWidgetAccess: true)
    }

    private func completeOnboardingViaReferral() {
        AppGroupConstants.activateReferralBypass()
        commitOnboardingAndFinish(grantWidgetAccess: true)
    }

    private func completeOnboardingAsFreeUser() {
        commitOnboardingAndFinish(grantWidgetAccess: false)
    }

    private func commitOnboardingAndFinish(grantWidgetAccess: Bool) {
        OnboardingReminderManager.cancelAbandonmentReminders()
        OfferNotificationManager.cancelOfferReminders()
        AppGroupConstants.commitOnboarding(
            tourPreference: draftTourPreference,
            favoritePlayerID: draftFavoritePlayerID,
            favoriteGrandSlam: draftFavoriteGrandSlam,
            grantWidgetAccess: grantWidgetAccess
        )
        if !grantWidgetAccess {
            AppGroupConstants.syncWidgetAccess(
                isProUser: revenueCat.isProUser,
                referralBypass: false
            )
        }
        hasCompletedOnboarding = true
        showSpecialOfferOnPaywall = false
    }

    private func returnToJoinScreen() {
        OnboardingReminderManager.cancelAbandonmentReminders()
        draftTourPreference = .both
        draftFavoritePlayerID = ""
        draftFavoriteGrandSlam = ""
        showSpecialOfferOnPaywall = false
        AppGroupConstants.clearOnboardingPreferences()
        CourtifyMotion.animateScreen(.backward) {
            navigationDirection = .backward
            path.removeAll()
        }
    }
}

#Preview {
    OnboardingFlowView()
}
