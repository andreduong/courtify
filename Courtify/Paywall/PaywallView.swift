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
        case .weekly: "$2.99/week"
        }
    }

    var subtitle: String {
        switch self {
        case .yearly: "Save 77% vs weekly"
        case .weekly: "Perfect for a grand slam"
        }
    }

    var badge: String? {
        switch self {
        case .yearly: "Best Value"
        case .weekly: nil
        }
    }
}

struct PaywallView: View {
    let favoritePlayerID: String
    var showSpecialOfferOnAppear = false

    @StateObject private var revenueCat = RevenueCatManager.shared

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var showCloseButton = false
    @State private var closeButtonOpacity: Double = 0
    @State private var showSpecialOffer = false

    let onSubscribed: () -> Void
    let onClose: () -> Void

    private var favoritePlayer: TennisPlayer? {
        TennisPlayer.player(for: favoritePlayerID)
    }

    var body: some View {
        ZStack {
            playerBackground

            Color.black.opacity(0.45).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 72)

                    VStack(spacing: 12) {
                        Text("Go Pro with Courtify")
                            .font(ThemeManager.roundedFont(.largeTitle, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Unlock live point-by-point, advanced stats, and ad-free Grand Slam coverage.")
                            .font(ThemeManager.roundedFont(.body))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    VStack(spacing: 12) {
                        ForEach(SubscriptionPlan.allCases) { plan in
                            PlanOptionRow(
                                plan: plan,
                                isSelected: selectedPlan == plan,
                                packagePrice: packagePrice(for: plan)
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
                        .font(ThemeManager.roundedFont(.footnote, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .courtifyButton(.ghost)
                    }

                    Text("Cancel anytime. Subscription auto-renews unless cancelled 24 hours before the period ends.")
                        .font(ThemeManager.roundedFont(.caption2))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 32)
                }
                .padding(24)
                .padding(.bottom, 8)
            }

            if showCloseButton {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            CourtifyMotion.animateModal {
                                showSpecialOffer = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .courtifyButton(.icon)
                        .opacity(closeButtonOpacity)
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 20)
                    Spacer()
                }
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
        }
        .ignoresSafeArea()
        .animation(CourtifyMotion.modal, value: showSpecialOffer)
        .navigationBarBackButtonHidden()
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
            scheduleCloseButton()
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
    private var playerBackground: some View {
        GeometryReader { geo in
            Group {
                if let player = favoritePlayer {
                    CachedBundledImage(name: player.paywallImageName, contentMode: .fill)
                } else {
                    ThemeManager.midnightGreen
                        .overlay {
                            Image(systemName: "tennisball.fill")
                                .font(.system(size: 120, weight: .bold, design: .rounded))
                                .foregroundStyle(ThemeManager.emeraldGreen.opacity(0.3))
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    private func packagePrice(for plan: SubscriptionPlan) -> String? {
        switch plan {
        case .yearly:
            revenueCat.yearlyPackage.map { "\($0.localizedPriceString)/year" }
        case .weekly:
            revenueCat.weeklyPackage.map { "\($0.localizedPriceString)/week" }
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
    let packagePrice: String?
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

                    Text(packagePrice ?? plan.price)
                        .font(ThemeManager.roundedFont(.title3, weight: .bold))
                        .foregroundStyle(ThemeManager.opticYellow)

                    Text(plan.subtitle)
                        .font(ThemeManager.roundedFont(.subheadline))
                        .foregroundStyle(.white.opacity(0.65))
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
