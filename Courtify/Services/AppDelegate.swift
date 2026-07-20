import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        OfferNotificationManager.registerCategories()
        AppIconManager.applyStoredLogoBall()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await RevenueCatManager.shared.refreshCustomerInfo()
        if RevenueCatManager.shared.isProUser || AppGroupConstants.referralBypassActive {
            OfferNotificationManager.cancelOfferReminders()
            OnboardingReminderManager.cancelAbandonmentReminders()
            return []
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let action = userInfo["action"] as? String else { return }

        await RevenueCatManager.shared.refreshCustomerInfo()
        guard !RevenueCatManager.shared.isProUser, !AppGroupConstants.referralBypassActive else {
            OfferNotificationManager.cancelOfferReminders()
            OnboardingReminderManager.cancelAbandonmentReminders()
            return
        }

        switch action {
        case "special_offer":
            PaywallDeepLink.shouldShowSpecialOffer = true
            NotificationCenter.default.post(name: .courtifyOpenSpecialOfferPaywall, object: nil)
        case "finish_onboarding":
            PaywallDeepLink.shouldOpenPaywall = true
            NotificationCenter.default.post(name: .courtifyOpenPaywall, object: nil)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let courtifyOpenSpecialOfferPaywall = Notification.Name("courtifyOpenSpecialOfferPaywall")
}
