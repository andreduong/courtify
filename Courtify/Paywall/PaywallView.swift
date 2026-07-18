import SwiftUI
import RevenueCat

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case yearly
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly: "Yearly"
        case .weekly: "Weekly"
        }
    }

    var price: String {
        switch self {
        case .yearly: "$34.99/year"
        case .weekly: "$4.99/week"
        }
    }

    var subtitle: String {
        switch self {
        case .yearly: "Save 85% vs weekly"
        case .weekly: "Perfect for a grand slam"
        }
    }

    var badge: String? {
        switch self {
        case .yearly: "Most Popular"
        case .weekly: nil
        }
    }

    var emphasizesSubtitle: Bool {
        self == .yearly
    }
}

struct PaywallView: View {
    let favoritePlayerID: String
    var showSpecialOfferOnAppear = false
    var managesOwnCloseButton = false

    @StateObject private var revenueCat = RevenueCatManager.shared

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var showCloseButton = false
    @State private var closeButtonOpacity: Double = 0
    @State private var showSpecialOffer = false

    let onSubscribed: () -> Void
    let onClose: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        ZStack {
            paywallBackground

            // Soft depth: keep marquee visible — widgets are the selling point.
            paywallFocusScrim
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: managesOwnCloseButton ? 72 : 16)

                    VStack(spacing: 12) {
                        Text("Courtify Premium")
                            .font(ThemeManager.roundedFont(.largeTitle, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.75), radius: 14, y: 2)
                            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)

                        Text("Unlock live point-by-point, advanced stats, and ad-free Grand Slam coverage.")
                            .font(ThemeManager.roundedFont(.body, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .shadow(color: .black.opacity(0.7), radius: 10, y: 1)
                    }

                    VStack(spacing: 14) {
                        ForEach(SubscriptionPlan.allCases) { plan in
                            PlanOptionRow(
                                plan: plan,
                                isSelected: selectedPlan == plan
                            ) {
                                CourtifyMotion.animateSelection {
                                    selectedPlan = plan
                                }
                            }
                        }
                    }

                    VStack(spacing: 14) {
                        Button {
                            Task { await purchaseSelectedPlan() }
                        } label: {
                            Group {
                                if revenueCat.isLoading {
                                    ProgressView()
                                        .tint(ThemeManager.midnightGreen)
                                } else {
                                    Text("Subscribe")
                                }
                            }
                            .courtifyPrimaryButtonLabel(cornerRadius: 16, verticalPadding: 18)
                        }
                        .courtifyButton(.primary, enabled: !revenueCat.isLoading)

                        Button("Restore Purchases") {
                            Task {
                                if await revenueCat.restorePurchases() {
                                    onSubscribed()
                                }
                            }
                        }
                        .font(ThemeManager.roundedFont(.footnote, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .courtifyButton(.ghost)
                        .shadow(color: .black.opacity(0.55), radius: 8, y: 1)
                    }

                    Text("Cancel anytime. Subscription auto-renews unless cancelled 24 hours before the period ends.")
                        .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.7), radius: 8, y: 1)
                        .padding(.bottom, 32)
                }
                .padding(24)
                .padding(.bottom, 8)
            }

            if showSpecialOffer {
                SpecialOfferPopup(
                    introPrice: revenueCat.yearlyIntroOfferPrice ?? "$24.99",
                    renewalPrice: revenueCat.yearlyStandardPrice ?? "$34.99",
                    isLoading: revenueCat.isLoading,
                    onClaim: {
                        Task { await claimSpecialOffer() }
                    },
                    onDismiss: dismissPaywallAfterOfferDeclined
                )
                .transition(CourtifyMotion.modalPresent)
                .zIndex(2)
            }

            if managesOwnCloseButton, showCloseButton {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            if let onSkip {
                                onSkip()
                            } else {
                                onClose()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.32))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .courtifyButton(.icon)
                        .opacity(closeButtonOpacity)
                    }
                    .padding(.top, CourtifyLayout.topSafeInset + 4)
                    .padding(.trailing, 20)
                    Spacer()
                }
                .zIndex(3)
            }
        }
        .animation(CourtifyMotion.modal, value: showSpecialOffer)
        .navigationBarBackButtonHidden()
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
            if managesOwnCloseButton {
                scheduleCloseButton()
            }
            if showSpecialOfferOnAppear {
                showSpecialOffer = true
                PaywallDeepLink.shouldShowSpecialOffer = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .courtifyOpenSpecialOfferPaywall)) { _ in
            CourtifyMotion.animateModal {
                showSpecialOffer = true
            }
        }
    }

    @ViewBuilder
    private var paywallBackground: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()
            // Full-bleed size so GeometryReader clip doesn't truncate the loop;
            // marquee still uses window safe-top to pin row 0 under the clock.
            CourtifyMarqueeBackground()
                .ignoresSafeArea()
        }
    }

    /// Soft wash so colorful widgets sit behind the CTA — still visible, not screaming.
    private var paywallFocusScrim: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.28),
                ],
                center: .center,
                startRadius: 220,
                endRadius: 680
            )
            .ignoresSafeArea()
        }
    }

    private func purchaseSelectedPlan() async {
        let package: Package?
        switch selectedPlan {
        case .yearly: package = revenueCat.yearlyPackage
        case .weekly: package = revenueCat.weeklyPackage
        }

        if let package, await revenueCat.purchase(package: package) {
            onSubscribed()
        }
    }

    private func claimSpecialOffer() async {
        guard let package = revenueCat.yearlyOfferPackage else { return }
        if await revenueCat.purchase(package: package) {
            onSubscribed()
        }
    }

    private func dismissPaywallAfterOfferDeclined() {
        CourtifyMotion.animateModal {
            showSpecialOffer = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            OfferNotificationManager.scheduleOfferRemindersIfNeeded()
            onClose()
        }
    }

    private func scheduleCloseButton() {
        showCloseButton = false
        closeButtonOpacity = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showCloseButton = true
            withAnimation(CourtifyMotion.reveal) {
                closeButtonOpacity = 1
            }
        }
    }
}

private struct SpecialOfferPopup: View {
    let introPrice: String
    let renewalPrice: String
    let isLoading: Bool
    let onClaim: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .courtifyButton(.icon)
                }

                Text("Special Offer")
                    .font(ThemeManager.roundedFont(.title2, weight: .bold))
                    .foregroundStyle(.white)

                Text("84% OFF")
                    .font(ThemeManager.roundedFont(size: 44, weight: .bold))
                    .foregroundStyle(ThemeManager.opticYellow)

                Text("\(introPrice) first year")
                    .font(ThemeManager.roundedFont(.title3, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Then \(renewalPrice)/year starting year 2. Cancel anytime.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Button(action: onClaim) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(ThemeManager.midnightGreen)
                        } else {
                            Text("Claim Offer")
                        }
                    }
                    .courtifyPrimaryButtonLabel(cornerRadius: 14)
                }
                .courtifyButton(.primary, enabled: !isLoading)

                Button("No thanks", action: onDismiss)
                    .font(ThemeManager.roundedFont(.footnote, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .courtifyButton(.ghost)
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ThemeManager.midnightGreen)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(ThemeManager.opticYellow.opacity(0.35), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct PlanOptionRow: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                            .foregroundStyle(.white)

                        if let badge = plan.badge {
                            Text(badge)
                                .font(ThemeManager.roundedFont(.caption2, weight: .bold))
                                .foregroundStyle(ThemeManager.midnightGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ThemeManager.opticYellow)
                                .clipShape(Capsule())
                        }
                    }

                    Text(plan.price)
                        .font(ThemeManager.roundedFont(.title3, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)

                    Text(plan.subtitle)
                        .font(
                            ThemeManager.roundedFont(
                                .subheadline,
                                weight: plan.emphasizesSubtitle ? .bold : .regular
                            )
                        )
                        .foregroundStyle(
                            plan.emphasizesSubtitle
                                ? ThemeManager.opticYellow
                                : .white.opacity(0.65)
                        )
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? ThemeManager.opticYellow : .white.opacity(0.3))
            }
            .glassCard(cornerRadius: 16, padding: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? ThemeManager.opticYellow : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .courtifySelection(isSelected)
        }
        .courtifyButton(.card)
    }
}

#Preview {
    PaywallView(favoritePlayerID: "djokovic", onSubscribed: {}, onClose: {})
        .courtifyBackground()
}
