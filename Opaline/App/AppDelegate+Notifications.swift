import UIKit
import UserNotifications

/// Legacy background fetch (single code path for iOS 12…latest — see
/// `configureLegacyBackgroundFetch`) and notification-tap handling.
extension AppDelegate {
    /// `@objc` is explicit: this is an optional protocol requirement
    /// implemented in an extension, and UIKit finds it through the ObjC
    /// runtime — without the attribute a silent miss is very hard to spot.
    @objc
    @available(iOS, deprecated: 13.0, message: "Single code path for iOS 12+.")
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler:
            @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AppLog.notifications("background fetch woke the app")
        BackgroundRefreshService.shared.refresh { refreshed in
            completionHandler(refreshed ? .newData : .noData)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Release-news alerts have been retired; discard any banner already queued by an old build.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            if let presenter = self?.topPresentableViewController() {
                YouTubeInboxViewController.present(from: presenter)
            }
            completionHandler()
        }
    }

    private func topPresentableViewController() -> UIViewController? {
        guard let root = window?.rootViewController,
              !(root is AuthViewController),
              !(root is SplashViewController)
        else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
