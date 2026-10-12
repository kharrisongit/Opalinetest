import Foundation
import UserNotifications

/// One-shot upgrades of stored defaults, run once per launch from
/// `application(_:didFinishLaunchingWithOptions:)`.
extension AppDelegate {
    func runMigrations() {
        OAuthClient.shared.migrateKeychainAccessibilityIfNeeded()
        migratePlaybackSourceToChain()
        retireReleaseNews()
    }

    private func retireReleaseNews() {
        let defaults = UserDefaults.standard
        let key = "utube_retiredReleaseNews"
        guard !defaults.bool(forKey: key) else {
            return
        }
        UpdateNotificationService.updatesEnabled = false
        let identifiers = AppNotificationStore.shared.notifications.map(\.id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        AppNotificationStore.shared.clear()
        defaults.set(true, forKey: key)
    }

    /// The old picker stored one source: `auto`, `android_vr`, `mweb_pot`,
    /// `tv` or `progressive`. Only a deliberate `tv` says anything the chain
    /// cannot express better — everyone else lands on the default chain, and
    /// the clients behind the other values are dead (Opaline#76).
    private func migratePlaybackSourceToChain() {
        let defaults = UserDefaults.standard
        let key = UserDefaultsKeys.Migration.playbackSourceAuto
        guard !defaults.bool(forKey: key) else {
            return
        }
        defaults.set(true, forKey: key)
        let legacyKey = "debug_playbackSource"
        if defaults.string(forKey: legacyKey) == "tv" {
            PlaybackChainSettings.order = ["tv.sabr"]
                + PlaybackChainSettings.defaultOrder.filter { $0 != "tv.sabr" }
            PlaybackChainSettings.enabled = ["tv.sabr"]
        }
        defaults.removeObject(forKey: legacyKey)
        defaults.removeObject(forKey: "debug_streamDelivery")
    }
}
