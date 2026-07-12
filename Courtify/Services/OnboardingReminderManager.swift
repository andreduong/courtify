import Foundation
import UserNotifications

enum OnboardingReminderManager {
    static let categoryID = "courtify.finish_onboarding"
    static let actionID = "courtify.open_paywall"

    private static let scheduledKey = "onboardingAbandonmentRemindersScheduled"

    private static let schedule: [(id: String, interval: TimeInterval)] = [
        ("courtify.onboarding.30m", 30 * 60),
        ("courtify.onboarding.1h", 60 * 60),
        ("courtify.onboarding.3h", 3 * 60 * 60),
        ("courtify.onboarding.24h", 24 * 60 * 60),
        ("courtify.onboarding.48h", 48 * 60 * 60),
        ("courtify.onboarding.5d", 5 * 24 * 60 * 60),
        ("courtify.onboarding.7d", 7 * 24 * 60 * 60),
    ]

    static var notificationIDs: [String] {
        schedule.map(\.id)
    }

    static func registerCategories() {
        OfferNotificationManager.registerCategories()
    }

    /// Schedule time-sensitive reminders from the moment the user backgrounds on the paywall.
    static func scheduleAbandonmentRemindersIfNeeded() {
        guard AppGroupConstants.notificationsEnabled else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: notificationIDs)

        let content = UNMutableNotificationContent()
        content.title = "You're almost done!"
        content.body = "Tap here to finish setting up Courtify"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = ["action": "finish_onboarding"]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        for entry in schedule {
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: entry.interval,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: entry.id,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        UserDefaults.standard.set(true, forKey: scheduledKey)
    }

    static func cancelAbandonmentReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: notificationIDs)
        UserDefaults.standard.set(false, forKey: scheduledKey)
    }
}

enum PaywallDeepLink {
    static let shouldShowSpecialOfferKey = "shouldShowSpecialOfferPaywall"
    static let shouldOpenPaywallKey = "shouldOpenPaywall"

    static var shouldShowSpecialOffer: Bool {
        get { UserDefaults.standard.bool(forKey: shouldShowSpecialOfferKey) }
        set { UserDefaults.standard.set(newValue, forKey: shouldShowSpecialOfferKey) }
    }

    static var shouldOpenPaywall: Bool {
        get { UserDefaults.standard.bool(forKey: shouldOpenPaywallKey) }
        set { UserDefaults.standard.set(newValue, forKey: shouldOpenPaywallKey) }
    }
}

extension Notification.Name {
    static let courtifyOpenPaywall = Notification.Name("courtifyOpenPaywall")
}
