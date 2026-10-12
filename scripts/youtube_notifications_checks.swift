import Foundation

extension String { var localized: String { self } }

enum InnertubeClient {
    static func simpleText(from value: Any?) -> String? { YouTubeCommentModel.text(value) }
    static func extractThumbnailURL(from value: Any?) -> String? {
        YouTubeCommentModel.thumbnailURL(value)
    }
}

@main
enum YouTubeNotificationsChecks {
    static var checks = 0
    enum Failure: Error { case failed(String) }

    static func expect(_ value: Bool, _ message: String) throws {
        guard value else { throw Failure.failed(message) }
        checks += 1
    }

    static func rejected(_ json: [String: Any]) throws {
        do {
            _ = try YouTubeNotificationModel.page(json)
            throw Failure.failed("Expected inbox rejection")
        } catch is YouTubeInboxError { checks += 1 }
    }

    static func menu(_ rows: [[String: Any]]) -> [String: Any] {
        ["actions": [["openPopupAction": ["popup": ["multiPageMenuRenderer": ["sections": [
            ["multiPageMenuNotificationSectionRenderer": ["items": rows]]
        ]]]]]]]
    }

    static func row(_ id: String) -> [String: Any] {
        ["notificationRenderer": [
            "notificationId": id,
            "shortMessage": ["runs": [["text": "@person"], ["text": " replied to your comment"]]],
            "sentTimeText": ["simpleText": "2 hours ago"], "read": false,
            "navigationEndpoint": [
                "watchEndpoint": ["videoId": "abc123def45"],
                "commandMetadata": ["webCommandMetadata": ["url": "/watch?v=abc123def45&lc=Ug.comment.reply"]]
            ],
            "contextualMenu": next("wrong-nested-token")
        ]]
    }

    static func next(_ token: String) -> [String: Any] {
        ["continuationItemRenderer": ["continuationEndpoint": [
            "continuationCommand": ["token": token]
        ]]]
    }

    static func main() throws {
        let page = try YouTubeNotificationModel.page(menu([row("one"), row("one"), row("two"), next("next")]))
        try expect(page.items.map(\.id) == ["one", "two"], "Order preserved and duplicate IDs removed")
        try expect(page.items[0].message == "@person replied to your comment", "Message runs combined")
        try expect(page.items[0].time == "2 hours ago", "Sent time parsed")
        try expect(!page.items[0].isRead, "Unread state retained")
        try expect(page.items[0].destination.videoID == "abc123def45", "Native video target")
        try expect(page.items[0].destination.commentID == "Ug.comment.reply", "Linked comment retained")
        try expect(page.continuation?.token == "next", "Only inbox continuation accepted")
        let final = try YouTubeNotificationModel.page(menu([row("one")]))
        try expect(final.continuation == nil, "Nested menu continuation never leaks into paging")
        let empty = try YouTubeNotificationModel.page(menu([]))
        try expect(empty.items.isEmpty && empty.continuation == nil, "Valid empty inbox")
        let nextPage = try YouTubeNotificationModel.page([
            "onResponseReceivedActions": [["appendContinuationItemsAction": [
                "continuationItems": [row("three"), next("four")]
            ]]]
        ])
        try expect(nextPage.items.first?.id == "three" && nextPage.continuation?.token == "four", "Next page shape")
        try rejected(["responseContext": [:]])
        try rejected(["error": ["code": 403]])
        var signedOut = menu([])
        signedOut["responseContext"] = ["mainAppWebResponseContext": ["loggedOut": true]]
        try rejected(signedOut)
        try expect(try YouTubeNotificationModel.unseenCount(["unseenCount": "4"]) == 4, "String count")
        try expect(try YouTubeNotificationModel.unseenCount([
            "actions": [["updateNotificationsUnseenCountAction": ["unseenCount": 3]]]
        ]) == 3, "Count action")
        try expect(try YouTubeNotificationModel.unseenCount(["unseenCount": -1]) == 0, "Nonnegative count")
        let replyBody = YouTubeInboxKind.replies.body(continuation: "token")
        try expect(replyBody["notificationsMenuRequestType"] as? String == "NOTIFICATIONS_MENU_REQUEST_TYPE_COMMENTS", "Replies filter")
        try expect((replyBody["fetchCommentsParams"] as? [String: String])?["continuation"] == "token", "Replies continuation envelope")
        try expect(replyBody["continuation"] == nil, "Replies never use inbox continuation")
        let replyPage = try YouTubeNotificationModel.page(menu([
            ["continuationItemRenderer": ["continuationEndpoint": ["continuationCommand": [
                "token": "reply-page", "request": "CONTINUATION_REQUEST_TYPE_COMMENTS_NOTIFICATION_MENU"
            ]]]]
        ]))
        try expect(replyPage.continuation?.kind == .replies, "Server continuation can change menu request kind")
        let allBody = YouTubeInboxKind.all.body(continuation: "all-token")
        try expect(allBody["continuation"] as? String == "all-token", "Inbox continuation envelope")
        try expect(YouTubeInboxKind.replies.body()["notificationsMenuRequestType"] as? String
                   == "NOTIFICATIONS_MENU_REQUEST_TYPE_INBOX", "Replies starts with the supported inbox request")
        try wrappedDestinations()
        try threadContents()
        try destinations()
        try previewPolicy()
        try profilesAndReplies()
        print("Passed \(checks) YouTube notification parsing, paging, and navigation checks")
    }

    static func previewPolicy() throws {
        for visible in [false, true] {
            for active in [false, true] {
                for main in [false, true] {
                    for airPlay in [false, true] {
                        let allowed = HomePreviewPolicy.allows(
                            visible: visible, active: active, mainPlayerInUse: main, airPlay: airPlay
                        )
                        if main || airPlay || !active || !visible {
                            try expect(!allowed, "Main/minimized video, AirPlay and background prohibit previews")
                        } else {
                            try expect(allowed, "Idle foreground carousel can preview")
                        }
                    }
                }
            }
        }
    }

    static func profilesAndReplies() throws {
        let old = Data("{\"id\":\"website-session\",\"title\":\"@me\"}".utf8)
        let restored = try JSONDecoder().decode(CommentAPIChannel.self, from: old)
        try expect(restored.avatarURL == nil && restored.title == "@me", "Old saved accounts still decode")
        let profile = try YouTubeCommentModel.account(["activeAccountHeaderRenderer": [
            "accountName": ["simpleText": "My Name"], "channelHandle": ["simpleText": "@me"],
            "accountPhoto": ["thumbnails": [["url": "https://yt3.ggpht.com/me.jpg"]]]
        ]])
        try expect(profile.title == "@me" && profile.avatarURL != nil, "Profile handle and photo")
        try expect(YouTubeCommentModel.thumbnailURL(["thumbnails": [["url": "file:///private/photo"]]]) == nil,
                   "Only HTTPS images")
        var photoRow = row("photo")
        var renderer = photoRow["notificationRenderer"] as! [String: Any]
        renderer["thumbnail"] = ["thumbnails": [["url": "https://yt3.ggpht.com/actor.jpg"]]]
        renderer["videoThumbnail"] = ["thumbnails": [["url": "https://i.ytimg.com/video.jpg"]]]
        photoRow["notificationRenderer"] = renderer
        let photo = try YouTubeNotificationModel.page(menu([photoRow])).items[0]
        try expect(photo.avatarURL != nil && photo.videoThumbnailURL != nil, "Notification images parsed")
        let parent: [String: Any] = ["commentViewModel": ["commentId": "root"]]
        let thread: [String: Any] = ["commentViewModel": parent,
            "replies": ["commentRepliesRenderer": ["contents": [
                ["commentViewModel": ["commentId": "linked-reply"]]
            ]]]]
        let page: [String: Any] = ["commentThreadRenderer": thread]
        try expect(NotificationReplyTarget.parentID(in: page, linkedID: "root") == "root", "Root notification")
        try expect(NotificationReplyTarget.parentID(in: page, linkedID: "linked-reply") == "root", "Nested reply's actual parent")
        try expect(NotificationReplyTarget.parentID(in: page, linkedID: "root.guessed") == nil, "Never guess ID prefixes")
        try expect(NotificationReplyTarget.parentID(in: page, linkedID: "unrelated") == nil, "Never pick unrelated first thread")
        try expect(NotificationReplyTarget.parentID(in: page, linkedID: "") == nil, "Empty link rejected")
        let conflicting: [String: Any] = ["threads": [page, ["commentThreadRenderer": [
            "commentViewModel": ["commentId": "other"],
            "replies": ["commentViewModel": ["commentId": "linked-reply"]]
        ]]]]
        try expect(NotificationReplyTarget.parentID(in: conflicting, linkedID: "linked-reply") == nil, "Ambiguous parent rejected")
    }

    static func wrappedDestinations() throws {
        let watch: [String: Any] = ["watchEndpoint": ["videoId": "abcdefghijk"],
            "commandMetadata": ["webCommandMetadata": ["url": "/watch?v=abcdefghijk&lc=reply"]]]
        let wrapped: [String: Any] = ["commandExecutorCommand": ["commands": [
            ["signalServiceEndpoint": ["signal": "IGNORE"]], ["innertubeCommand": watch]
        ]]]
        let destination = YouTubeNotificationDestination(endpoint: wrapped)
        try expect(destination.videoID == "abcdefghijk" && destination.commentID == "reply",
                   "Wrapped notification commands retain the exact linked comment")
        let poison = YouTubeNotificationDestination(endpoint: ["contextualMenu": watch])
        try expect(poison.videoID == nil, "Unrelated context menu cannot choose a notification destination")
        let legacy = try YouTubeNotificationModel.page(menu([
            ["continuationItemRenderer": ["continuationEndpoint": [
                "getNotificationMenuEndpoint": ["ctoken": "older-inbox"]]]]
        ]))
        try expect(legacy.continuation?.token == "older-inbox", "Legacy inbox paging token retained")
        let reply = try YouTubeNotificationModel.page(menu([row("one")])).items[0]
        let video = YouTubeNotification(id: "video", message: "A new upload", time: "now", isRead: false,
            destination: YouTubeNotificationDestination(endpoint: ["watchEndpoint": ["videoId": "abcdefghijk"]]))
        try expect([video, reply].filter(\.isComment).map(\.id) == ["one"],
                   "Replies filters linked comments without depending on English notification text")
    }

    static func threadContents() throws {
        func comment(_ id: String) -> [String: Any] {
            ["commentViewModel": ["commentId": id, "commentKey": "key-" + id]]
        }
        func entity(_ id: String) -> [String: Any] {
            ["payload": ["commentEntityPayload": ["key": "key-" + id,
                "author": ["displayName": "@" + id],
                "properties": ["commentId": id, "content": ["content": "Text for " + id]]]]]
        }
        let thread: [String: Any] = ["commentThreadRenderer": [
            "commentViewModel": comment("root"),
            "replies": ["commentRepliesRenderer": ["contents": [comment("linked"), next("replies-only")]]]
        ]]
        let json: [String: Any] = [
            "onResponseReceivedEndpoints": [["reloadContinuationItemsCommand": [
                "continuationItems": [thread, next("unrelated-video-comments")]]]],
            "frameworkUpdates": ["entityBatchUpdate": ["mutations": [entity("root"), entity("linked")]]]
        ]
        let page = try NotificationThreadPage.parse(json, linkedID: "linked")
        try expect(page.parent.id == "root" && page.replies.map(\.id) == ["linked"],
                   "Thread includes both its parent and the linked nested reply")
        try expect(page.continuation == "replies-only", "Thread paging never wanders into the video comment feed")
        try expect(page.replies.first?.authorName == "@linked", "Nested reply recipient is retained")
        do {
            _ = try NotificationThreadPage.parse(json, linkedID: "unrelated")
            throw Failure.failed("Unrelated thread accepted")
        } catch is CommentAPIError { checks += 1 }
    }

    static func destinations() throws {
        let relative = YouTubeNotificationDestination(endpoint: [
            "commandMetadata": ["webCommandMetadata": ["url": "/watch?v=abcdefghijk&lc=reply"]]
        ])
        try expect(relative.videoID == "abcdefghijk" && relative.commentID == "reply", "Relative URL fallback")
        let channel = YouTubeNotificationDestination(endpoint: ["browseEndpoint": ["browseId": "UCexample"]])
        try expect(channel.channelID == "UCexample", "Native channel navigation")
        for url in ["https://youtube.com.evil.test/watch?v=id", "//evil.test", "javascript:alert(1)", "http://www.youtube.com/watch", "https://secret@www.youtube.com/watch", "https://www.youtube.com:8443/watch"] {
            try expect(YouTubeNotificationDestination.safeURL(url) == nil, "Reject unsafe destination")
        }
        try expect(YouTubeNotificationDestination.safeURL("https://www.youtube.com/post/test") != nil, "Explicit YouTube fallback allowed")
    }
}
