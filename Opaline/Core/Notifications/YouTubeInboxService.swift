import UIKit

/// Main-thread owned. Notification text and read state never enter disk caches.
final class YouTubeInboxService {
    static let shared = YouTubeInboxService()
    static let didChange = Notification.Name("youtubeInboxDidChange")
    private(set) var unseenCount = 0
    private(set) var readIDs = Set<String>()
    private var lastCheck = Date.distantPast
    private var generation = 0
    private var checking = false
    private var timer: Timer?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: YouTubeCommentClient.didChange,
            object: nil
        )
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshCount()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCount),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc
    private func accountChanged() {
        generation += 1
        checking = false
        unseenCount = 0
        readIDs = []
        lastCheck = .distantPast
        notify()
        refreshCount()
    }

    @objc
    func refreshCount() {
        guard YouTubeCommentClient.shared.channel != nil, !checking,
              UIApplication.shared.applicationState == .active,
              Date().timeIntervalSince(lastCheck) > 60 else {
            return
        }
        checking = true
        lastCheck = Date()
        let expected = generation
        YouTubeCommentClient.shared.readNotifications(
            body: [:], countOnly: true
        ) { [weak self] result in
            guard let self, self.generation == expected else {
                return
            }
            self.checking = false
            if let count = try? YouTubeNotificationModel.unseenCount(result.get()) {
                self.unseenCount = count
                self.notify()
            }
        }
    }

    func openedInbox() {
        generation += 1
        checking = false
        unseenCount = 0
        lastCheck = Date()
        notify()
    }

    func markRead(_ id: String) {
        readIDs.insert(id)
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
