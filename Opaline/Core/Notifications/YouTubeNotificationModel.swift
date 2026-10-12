import Foundation

/// Parses the inbox containers, never a continuation hidden in a row's menu or navigation action.
enum YouTubeNotificationModel {
    static func validate(_ json: [String: Any]) throws {
        let context = json["responseContext"] as? [String: Any]
        let web = context?["mainAppWebResponseContext"] as? [String: Any]
        if web?["loggedOut"] as? Bool == true {
            throw YouTubeInboxError(reason: "signedOut")
        }
        guard json["error"] == nil else {
            throw YouTubeInboxError(reason: "load")
        }
    }

    static func page(_ json: [String: Any]) throws -> YouTubeNotificationPage {
        try validate(json)
        let containers = actions(json).compactMap(items)
        guard !containers.isEmpty else {
            throw YouTubeInboxError(reason: "load")
        }
        var notifications: [YouTubeNotification] = []
        var seen = Set<String>()
        var token: YouTubeInboxContinuation?
        for row in containers.flatMap({ $0 }) {
            if let item = notification(row), seen.insert(item.id).inserted {
                notifications.append(item)
            }
            if let next = continuation(row) {
                token = next
            }
        }
        return YouTubeNotificationPage(items: notifications, continuation: token)
    }

    static func unseenCount(_ json: [String: Any]) throws -> Int {
        try validate(json)
        if let count = count(json["unseenCount"]) {
            return count
        }
        for action in actions(json) {
            let update = action["updateNotificationsUnseenCountAction"] as? [String: Any]
            if let count = count(update?["unseenCount"]) {
                return count
            }
        }
        throw YouTubeInboxError(reason: "load")
    }

    private static func count(_ value: Any?) -> Int? {
        let count = value as? Int ?? (value as? String).flatMap(Int.init)
        return count.map { max(0, $0) }
    }

    private static func actions(_ json: [String: Any]) -> [[String: Any]] {
        ["actions", "onResponseReceivedActions", "onResponseReceivedEndpoints"]
            .flatMap { json[$0] as? [[String: Any]] ?? [] }
    }

    private static func items(_ action: [String: Any]) -> [[String: Any]]? {
        for key in ["appendContinuationItemsAction", "reloadContinuationItemsCommand"] {
            if let command = action[key] as? [String: Any],
               let rows = command["continuationItems"] as? [[String: Any]] {
                return rows
            }
        }
        let popupAction = action["openPopupAction"] as? [String: Any]
        let popup = popupAction?["popup"] as? [String: Any]
        guard let menu = popup?["multiPageMenuRenderer"] as? [String: Any],
              let sections = menu["sections"] as? [[String: Any]]
        else {
            return nil
        }
        return sections.flatMap { section -> [[String: Any]] in
            let content = section["multiPageMenuNotificationSectionRenderer"] as? [String: Any]
                ?? section["multiPageMenuSectionRenderer"] as? [String: Any]
            return content?["items"] as? [[String: Any]] ?? []
        }
    }

    private static func notification(_ row: [String: Any]) -> YouTubeNotification? {
        guard let renderer = row["notificationRenderer"] as? [String: Any],
              let id = renderer["notificationId"] as? String, !id.isEmpty
        else {
            return nil
        }
        guard let message = YouTubeCommentModel.text(renderer["shortMessage"]),
              !message.isEmpty else {
            return nil
        }
        return YouTubeNotification(
            id: id,
            message: message,
            time: YouTubeCommentModel.text(renderer["sentTimeText"]) ?? "",
            isRead: renderer["read"] as? Bool ?? false,
            destination: YouTubeNotificationDestination(
                endpoint: renderer["navigationEndpoint"] as? [String: Any] ?? [:]
            ),
            avatarURL: YouTubeCommentModel.thumbnailURL(renderer["thumbnail"]),
            videoThumbnailURL: YouTubeCommentModel.thumbnailURL(renderer["videoThumbnail"])
        )
    }

    private static func continuation(_ row: [String: Any]) -> YouTubeInboxContinuation? {
        let renderer = row["continuationItemRenderer"] as? [String: Any]
        let endpoint = renderer?["continuationEndpoint"] as? [String: Any]
        let command = endpoint?["continuationCommand"] as? [String: Any]
        guard let token = command?["token"] as? String, !token.isEmpty else {
            return nil
        }
        let request = command?["request"] as? String
        let isReplies = request == "CONTINUATION_REQUEST_TYPE_COMMENTS_NOTIFICATION_MENU"
        let kind: YouTubeInboxKind = isReplies ? .replies : .all
        return YouTubeInboxContinuation(token: token, kind: kind)
    }
}
