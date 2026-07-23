import Foundation
import UserNotifications

enum OfferNotificationManager {
    static let specialOfferCategoryID = "courtify.special_offer"
    static let specialOfferActionID = "courtify.claim_offer"

    private static let scheduledKey = "offerNotificationsScheduled"
    private static let notificationIDs = [
        "courtify.offer.12h",
        "courtify.offer.24h",
        "courtify.offer.48h"
    ]

    private static let intervals: [TimeInterval] = [
        12 * 60 * 60,
        24 * 60 * 60,
        48 * 60 * 60
    ]

    /// Called from onboarding when the user explicitly opts in — shows the iOS permission sheet.
    @discardableResult
    static func requestAuthorizationFromUser() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            AppGroupConstants.setNotificationsEnabled(true)
            return true
        case .denied:
            AppGroupConstants.setNotificationsEnabled(false)
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
                AppGroupConstants.setNotificationsEnabled(granted)
                return granted
            } catch {
                AppGroupConstants.setNotificationsEnabled(false)
                return false
            }
        @unknown default:
            AppGroupConstants.setNotificationsEnabled(false)
            return false
        }
    }

    static func refreshAuthorizationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        AppGroupConstants.setNotificationsEnabled(isEnabled)
    }

    static func registerCategories() {
        let claimAction = UNNotificationAction(
            identifier: specialOfferActionID,
            title: "Claim Offer",
            options: [.foreground]
        )
        let offerCategory = UNNotificationCategory(
            identifier: specialOfferCategoryID,
            actions: [claimAction],
            intentIdentifiers: [],
            options: []
        )

        let continueAction = UNNotificationAction(
            identifier: OnboardingReminderManager.actionID,
            title: "Continue Setup",
            options: [.foreground]
        )
        let onboardingCategory = UNNotificationCategory(
            identifier: OnboardingReminderManager.categoryID,
            actions: [continueAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            offerCategory,
            onboardingCategory,
        ])
    }

    static func scheduleOfferRemindersIfNeeded() {
        guard isEligibleForSubscriptionReminders else {
            cancelSubscriptionRemindersIfEntitled()
            return
        }
        guard !UserDefaults.standard.bool(forKey: scheduledKey) else { return }
        scheduleOfferReminders()
    }

    static func scheduleOfferReminders() {
        guard isEligibleForSubscriptionReminders else {
            cancelSubscriptionRemindersIfEntitled()
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let existingIDs = Set(requests.map(\.identifier))
            let hasPending = notificationIDs.contains { existingIDs.contains($0) }
            if hasPending { return }

            let content = UNMutableNotificationContent()
            content.title = "Courtify Premium"
            content.body = "Claim your 84% off Courtify Premium offer."
            content.sound = .default
            content.categoryIdentifier = specialOfferCategoryID
            content.userInfo = ["action": "special_offer"]

            for (id, interval) in zip(notificationIDs, intervals) {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }

            UserDefaults.standard.set(true, forKey: scheduledKey)
        }
    }

    static func cancelOfferReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: notificationIDs)
        UserDefaults.standard.set(false, forKey: scheduledKey)
    }

    /// Subscription nudges are for free users only — never schedule or keep for Pro / referral.
    private static var isEligibleForSubscriptionReminders: Bool {
        AppGroupConstants.notificationsEnabled && !AppGroupConstants.widgetAccessEnabled
    }

    /// Clears offer + onboarding abandonment reminders when the user is entitled.
    static func cancelSubscriptionRemindersIfEntitled() {
        guard AppGroupConstants.widgetAccessEnabled else { return }
        cancelOfferReminders()
        OnboardingReminderManager.cancelAbandonmentReminders()
    }
}
