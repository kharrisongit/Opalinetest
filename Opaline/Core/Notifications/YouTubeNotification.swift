import Foundation

enum YouTubeInboxKind: Hashable {
    case all, replies

    var requestType: String {
        switch self {
        case .all:
            return "NOTIFICATIONS_MENU_REQUEST_TYPE_INBOX"
        case .replies:
            return "NOTIFICATIONS_MENU_REQUEST_TYPE_COMMENTS"
        }
    }

    func body(continuation: String? = nil) -> [String: Any] {
        var body: [String: Any] = ["notificationsMenuRequestType": requestType]
        if let continuation {
            if self == .replies {
                body["fetchCommentsParams"] = ["continuation": continuation]
            } else {
                body["continuation"] = continuation
            }
        }
        return body
    }
}

struct YouTubeNotification {
    let id: String
    let message: String
    let time: String
    let isRead: Bool
    let destination: YouTubeNotificationDestination
}

struct YouTubeNotificationPage {
    let items: [YouTubeNotification]
    let continuation: YouTubeInboxContinuation?
}

struct YouTubeInboxContinuation: Hashable {
    let token: String
    let kind: YouTubeInboxKind
}

struct YouTubeInboxError: LocalizedError {
    let reason: String

    var errorDescription: String? { "youtubeInbox.error.\(reason)".localized }
}
