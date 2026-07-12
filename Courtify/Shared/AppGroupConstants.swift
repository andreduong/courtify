import Foundation

enum AppGroupConstants {
    static let suiteName = "group.com.courtify.xyz"

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    static var playerImagesDirectory: URL? {
        containerURL?.appendingPathComponent("player-images", isDirectory: true)
    }

    enum Keys {
        static let favoritePlayerID = "favoritePlayerID"
        static let tourPreference = "tourPreference"
        static let favoriteGrandSlam = "favoriteGrandSlam"
        static let useMockWidgetData = "useMockWidgetData"
        static let referralBypassActive = "referralBypassActive"
        static let notificationsEnabled = "notificationsEnabled"
        #if DEBUG
        static let debugProUser = "debugProUser"
        #endif
    }

    static var referralBypassActive: Bool {
        userDefaults.bool(forKey: Keys.referralBypassActive)
    }

    static func activateReferralBypass() {
        userDefaults.set(true, forKey: Keys.referralBypassActive)
    }

    static var notificationsEnabled: Bool {
        userDefaults.bool(forKey: Keys.notificationsEnabled)
    }

    static func setNotificationsEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.notificationsEnabled)
    }

    #if DEBUG
    static var debugProUserEnabled: Bool {
        if ProcessInfo.processInfo.environment["COURTIFY_DEBUG_PRO"] == "1" {
            return true
        }
        return userDefaults.bool(forKey: Keys.debugProUser)
    }
    #endif

    static var useMockWidgetData: Bool {
        #if DEBUG
        if userDefaults.object(forKey: Keys.useMockWidgetData) == nil {
            return true
        }
        return userDefaults.bool(forKey: Keys.useMockWidgetData)
        #else
        return false
        #endif
    }

    static func setUseMockWidgetData(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.useMockWidgetData)
    }

    static func commitOnboarding(
        tourPreference: TourPreference,
        favoritePlayerID: String,
        favoriteGrandSlam: String
    ) {
        userDefaults.set(tourPreference.rawValue, forKey: Keys.tourPreference)
        userDefaults.set(favoritePlayerID, forKey: Keys.favoritePlayerID)
        userDefaults.set(favoriteGrandSlam, forKey: Keys.favoriteGrandSlam)
        WidgetTimelineRefresher.reloadAll()
    }

    static func clearOnboardingPreferences() {
        userDefaults.removeObject(forKey: Keys.tourPreference)
        userDefaults.removeObject(forKey: Keys.favoritePlayerID)
        userDefaults.removeObject(forKey: Keys.favoriteGrandSlam)
        userDefaults.removeObject(forKey: Keys.referralBypassActive)
        userDefaults.removeObject(forKey: Keys.notificationsEnabled)
        WidgetTimelineRefresher.reloadAll()
    }

    static func updateFavoritePlayer(_ playerID: String) {
        userDefaults.set(playerID, forKey: Keys.favoritePlayerID)
        WidgetTimelineRefresher.reloadAll()
    }

    static func clearWidgetFavorites() {
        userDefaults.removeObject(forKey: Keys.favoritePlayerID)
        userDefaults.removeObject(forKey: Keys.favoriteGrandSlam)
        WidgetTimelineRefresher.reloadAll()
    }
}
