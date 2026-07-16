import Foundation

enum AppGroupConstants {
    static let suiteName = "group.com.courtify.xyz"

    static var userDefaults: UserDefaults {
        appGroupStorage
    }

    /// Shared store for `@AppStorage` in SwiftUI views (must match `userDefaults`).
    static let appGroupStorage = UserDefaults(suiteName: suiteName) ?? .standard

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    static var playerImagesDirectory: URL? {
        containerURL?.appendingPathComponent("player-images", isDirectory: true)
    }

    static let favoritePlayerDidChange = Notification.Name("favoritePlayerDidChange")
    static let widgetColorDidChange = Notification.Name("widgetColorDidChange")

    enum Keys {
        static let favoritePlayerID = "favoritePlayerID"
        static let favoritePlayerRevision = "favoritePlayerRevision"
        static let favoritePlayerWidgetIntentID = "favoritePlayerWidgetIntentID"
        static let favoritePlayerWidgetRevision = "favoritePlayerWidgetRevision"
        static let tourPreference = "tourPreference"
        static let favoriteGrandSlam = "favoriteGrandSlam"
        static let useMockWidgetData = "useMockWidgetData"
        static let didFetchOnboardingRankings = "didFetchOnboardingRankings"
        static let widgetDataPayloadCache = "widgetDataPayloadCache"
        static let referralBypassActive = "referralBypassActive"
        static let widgetAccessEnabled = "widgetAccessEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let widgetColorStyles = "widgetColorStyles"
        #if DEBUG
        static let debugProUser = "debugProUser"
        #endif
    }

    static var referralBypassActive: Bool {
        userDefaults.bool(forKey: Keys.referralBypassActive)
    }

    static func activateReferralBypass() {
        userDefaults.set(true, forKey: Keys.referralBypassActive)
        setWidgetAccessEnabled(true)
    }

    /// Widgets only show live data for Pro subscribers or valid referral bypass.
    static var widgetAccessEnabled: Bool {
        userDefaults.bool(forKey: Keys.widgetAccessEnabled)
    }

    static func setWidgetAccessEnabled(_ enabled: Bool) {
        let previous = widgetAccessEnabled
        userDefaults.set(enabled, forKey: Keys.widgetAccessEnabled)
        if previous != enabled {
            WidgetTimelineRefresher.reloadAll()
        }
    }

    static func syncWidgetAccess(isProUser: Bool, referralBypass: Bool? = nil) {
        let bypass = referralBypass ?? referralBypassActive
        setWidgetAccessEnabled(isProUser || bypass)
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
        favoriteGrandSlam: String,
        grantWidgetAccess: Bool = true
    ) {
        userDefaults.set(tourPreference.rawValue, forKey: Keys.tourPreference)
        userDefaults.set(favoriteGrandSlam, forKey: Keys.favoriteGrandSlam)
        // Bump revision + notify so Home / widgets refresh immediately.
        if favoritePlayerID.isEmpty {
            userDefaults.removeObject(forKey: Keys.favoritePlayerID)
        } else {
            updateFavoritePlayer(favoritePlayerID)
        }
        if grantWidgetAccess {
            setWidgetAccessEnabled(true)
        } else {
            WidgetTimelineRefresher.reloadAll()
        }
    }

    /// Write-through while onboarding so picks survive paywall races / process death.
    static func persistOnboardingDraft(
        tourPreference: TourPreference? = nil,
        favoritePlayerID: String? = nil,
        favoriteGrandSlam: String? = nil
    ) {
        if let tourPreference {
            userDefaults.set(tourPreference.rawValue, forKey: Keys.tourPreference)
        }
        if let favoritePlayerID {
            userDefaults.set(favoritePlayerID, forKey: Keys.favoritePlayerID)
        }
        if let favoriteGrandSlam {
            userDefaults.set(favoriteGrandSlam, forKey: Keys.favoriteGrandSlam)
        }
    }

    static func clearOnboardingPreferences() {
        userDefaults.removeObject(forKey: Keys.tourPreference)
        userDefaults.removeObject(forKey: Keys.favoritePlayerID)
        userDefaults.removeObject(forKey: Keys.favoriteGrandSlam)
        userDefaults.removeObject(forKey: Keys.referralBypassActive)
        userDefaults.removeObject(forKey: Keys.notificationsEnabled)
        setWidgetAccessEnabled(false)
        WidgetTimelineRefresher.reloadAll()
    }

    static func updateFavoritePlayer(_ playerID: String) {
        let revision = userDefaults.integer(forKey: Keys.favoritePlayerRevision) + 1
        userDefaults.set(playerID, forKey: Keys.favoritePlayerID)
        userDefaults.set(revision, forKey: Keys.favoritePlayerRevision)
        WidgetTimelineRefresher.reloadAll()
        NotificationCenter.default.post(name: favoritePlayerDidChange, object: playerID)
    }

    static var favoritePlayerRevision: Int {
        userDefaults.integer(forKey: Keys.favoritePlayerRevision)
    }

    static var favoritePlayerWidgetRevision: Int {
        userDefaults.integer(forKey: Keys.favoritePlayerWidgetRevision)
    }

    static func markFavoritePlayerWidgetRevisionSynced() {
        userDefaults.set(favoritePlayerRevision, forKey: Keys.favoritePlayerWidgetRevision)
    }

    /// Clears stale player photo/rank caches from earlier builds or failed API lookups.
    static func migratePlayerCachesIfNeeded() {
        let versionKey = "playerCacheSchemaVersion"
        let currentVersion = 2
        guard userDefaults.integer(forKey: versionKey) < currentVersion else { return }

        PlayerRankCache.clearAll()
        PlayerSeasonRecordCache.clearAll()
        PlayerPhotoStore.clearAllCachedPhotos()
        userDefaults.set(currentVersion, forKey: versionKey)
    }

    static func clearWidgetFavorites() {
        userDefaults.removeObject(forKey: Keys.favoritePlayerID)
        userDefaults.removeObject(forKey: Keys.favoriteGrandSlam)
        WidgetTimelineRefresher.reloadAll()
    }
}
