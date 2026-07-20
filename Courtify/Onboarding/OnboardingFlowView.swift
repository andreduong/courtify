import SwiftUI

enum OnboardingStep: Hashable {
    case splash
    case tourPreference
    case favoritePlayers
    case favoriteGrandSlam
    case notifications
    case referralCode
    case allSet
    case paywall
}

struct OnboardingFlowView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    /// Drafts write to the same app-group keys Home/Settings read — progressive persistence.
    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.appGroupStorage)
    private var draftTourPreferenceRaw = TourPreference.both.rawValue
    @AppStorage(AppGroupConstants.Keys.favoritePlayerID, store: AppGroupConstants.appGroupStorage)
    private var draftFavoritePlayerID = ""
    @AppStorage(AppGroupConstants.Keys.favoriteGrandSlam, store: AppGroupConstants.appGroupStorage)
    private var draftFavoriteGrandSlam = ""
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var path: [OnboardingStep] = []
    @State private var navigationDirection: CourtifyMotion.Direction = .forward
    @State private var showSpecialOfferOnPaywall = false

    private var draftTourPreference: TourPreference {
        get { TourPreference(rawValue: draftTourPreferenceRaw) ?? .both }
        nonmutating set { draftTourPreferenceRaw = newValue.rawValue }
    }

    private var draftTourPreferenceBinding: Binding<TourPreference> {
        Binding(
            get: { draftTourPreference },
            set: { draftTourPreferenceRaw = $0.rawValue }
        )
    }

    private var onboardingProgress: Double {
        OnboardingProgress.progress(for: path)
    }

    private var showsBackButton: Bool {
        !path.isEmpty
    }

    private var showsOnboardingChrome: Bool {
        guard let last = path.last else { return false }
        // Paywall owns full-bleed marquee + close — chrome inset would paint a solid band over it.
        return last != .allSet && last != .paywall
    }

    var body: some View {
        let flow = CourtifyScreenFlow(path: $path, direction: $navigationDirection) {
            SplashScreenView {
                navigateForward(.tourPreference)
            }
        } destination: { step in
            destinationView(for: step)
        }

        Group {
            if showsOnboardingChrome {
                flow
                    .safeAreaInset(edge: .top, spacing: 0) {
                        OnboardingChrome(
                            progress: onboardingProgress,
                            showsBackButton: showsBackButton,
                            onBack: navigateBackward,
                            showsCloseButton: false,
                            closeButtonOpacity: 0,
                            onClose: completeOnboardingAsFreeUser
                        )
                    }
            } else {
                flow
            }
        }
        .courtifyBackground()
        .task {
            // First-ever open: fetch real rankings once so the favorite-player
            // step shows the actual top 10 instead of bundled placeholders.
            await WidgetDataStore.shared.refreshOnceForOnboarding()
        }
        .onAppear {
            openSpecialOfferPaywallIfNeeded()
            openPaywallIfNeeded()
            #if DEBUG
            openPaywallForUITestIfNeeded()
            #endif
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
            TourPreferenceView(tourPreference: draftTourPreferenceBinding) {
                AppGroupConstants.persistOnboardingDraft(tourPreference: draftTourPreference)
                navigateForward(.favoritePlayers)
            }
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .favoritePlayers:
            FavoritePlayersView(
                tourPreference: draftTourPreference,
                favoritePlayerID: $draftFavoritePlayerID
            ) {
                AppGroupConstants.persistOnboardingDraft(favoritePlayerID: draftFavoritePlayerID)
                navigateForward(.favoriteGrandSlam)
            }
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .favoriteGrandSlam:
            FavoriteGrandSlamView(favoriteGrandSlam: $draftFavoriteGrandSlam) {
                AppGroupConstants.persistOnboardingDraft(favoriteGrandSlam: draftFavoriteGrandSlam)
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
                onSkip: { navigateForward(.allSet) }
            )
            .courtifyScreenContent()
            .padding(.top, onboardingContentTopInset)
        case .allSet:
            CourtifyLoadingScreen()
                .task {
                    // Brief beat so the transition reads before paywall.
                    try? await Task.sleep(for: .milliseconds(650))
                    guard path.last == .allSet else { return }
                    navigateForward(.paywall)
                }
        case .paywall:
            PaywallView(
                favoritePlayerID: draftFavoritePlayerID,
                showSpecialOfferOnAppear: showSpecialOfferOnPaywall,
                managesOwnCloseButton: true,
                onSubscribed: completeOnboarding,
                onClose: completeOnboardingAsFreeUser,
                onSkip: completeOnboardingAsFreeUser
            )
        }
    }

    private var onboardingContentTopInset: CGFloat {
        8
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
                    path = [.tourPreference, .favoritePlayers, .favoriteGrandSlam, .notifications, .referralCode, .allSet, .paywall]
                } else if !path.contains(.paywall) {
                    if path.last == .allSet {
                        path.append(.paywall)
                    } else if !path.contains(.allSet) {
                        path.append(.allSet)
                    } else {
                        path.append(.paywall)
                    }
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
                    path = [.tourPreference, .favoritePlayers, .favoriteGrandSlam, .notifications, .referralCode, .allSet, .paywall]
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
        if let player = FavoritePlayerCatalog.resolvedPlayer(
            id: draftFavoritePlayerID,
            payload: WidgetDataStore.shared.payload
        ), player.imageName == nil {
            Task {
                await FavoritePlayerEnricher.enrich(
                    player,
                    payload: WidgetDataStore.shared.payload,
                    clearExisting: false
                )
            }
        }
        hasCompletedOnboarding = true
        showSpecialOfferOnPaywall = false
    }

    private func returnToJoinScreen() {
        OnboardingReminderManager.cancelAbandonmentReminders()
        showSpecialOfferOnPaywall = false
        AppGroupConstants.clearOnboardingPreferences()
        draftTourPreferenceRaw = TourPreference.both.rawValue
        draftFavoritePlayerID = ""
        draftFavoriteGrandSlam = ""
        CourtifyMotion.animateScreen(.backward) {
            navigationDirection = .backward
            path.removeAll()
        }
    }

    #if DEBUG
    private func openPaywallForUITestIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-UITestPaywall") else { return }
        draftFavoritePlayerID = "sinner"
        draftFavoriteGrandSlam = "Wimbledon"
        path = [.tourPreference, .favoritePlayers, .favoriteGrandSlam, .notifications, .referralCode, .allSet, .paywall]
    }
    #endif
}

#Preview {
    OnboardingFlowView()
}
