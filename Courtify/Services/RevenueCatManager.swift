import Foundation
import RevenueCat

enum SubscriptionProductID {
    static let weekly = "com.courtify.xyz.premium.weekly"
    /// Main paywall yearly — no introductory offer; always full price.
    static let yearly = "com.courtify.xyz.premium.yearly"
    /// Exit-popup only. Standard price matches yearly; intro offer configured in App Store Connect.
    static let yearlyOffer = "com.courtify.xyz.premium.yearly_offer"
}

@MainActor
final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var offerings: Offerings?
    @Published private(set) var isProUser = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var isConfigured = false

    private init() {}

    func prepareForLaunch() async {
        if !isConfigured {
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: "appl_zeziQcPanatZmneULVfhzUDlkSE")
            isConfigured = true
        }
        await refreshCustomerInfo()
        await loadOfferings()
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        isProUser = info.entitlements["pro"]?.isActive == true
        AppGroupConstants.syncWidgetAccess(isProUser: isProUser)
        if isProUser {
            OfferNotificationManager.cancelOfferReminders()
            OnboardingReminderManager.cancelAbandonmentReminders()
        }
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(package: Package) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            applyCustomerInfo(result.customerInfo)
            return isProUser
        } catch {
            let rcError = error as NSError
            if rcError.domain != RevenueCat.ErrorCode.errorDomain
                || rcError.code != RevenueCat.ErrorCode.purchaseCancelledError.rawValue {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            return isProUser
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var weeklyPackage: Package? {
        package(matching: SubscriptionProductID.weekly, type: .weekly)
    }

    var yearlyPackage: Package? {
        package(matching: SubscriptionProductID.yearly, type: .annual)
    }

    /// Only surfaced in the exit-popup flow — never on the main paywall.
    var yearlyOfferPackage: Package? {
        package(matching: SubscriptionProductID.yearlyOffer, type: .annual)
    }

    var yearlyIntroOfferPrice: String? {
        yearlyOfferPackage?.storeProduct.introductoryDiscount?.localizedPriceString
    }

    var yearlyStandardPrice: String? {
        yearlyOfferPackage?.localizedPriceString ?? yearlyPackage?.localizedPriceString
    }

    private func package(matching productID: String, type: PackageType) -> Package? {
        if let match = offerings?.current?.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == productID
        }) {
            return match
        }

        switch type {
        case .weekly:
            return offerings?.current?.weekly
                ?? offerings?.current?.availablePackages.first { $0.packageType == .weekly }
        case .annual:
            return offerings?.current?.annual
                ?? offerings?.current?.availablePackages.first { $0.packageType == .annual }
        default:
            return nil
        }
    }
}
