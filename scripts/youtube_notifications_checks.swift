import Foundation

extension String { var localized: String { self } }

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
        try destinations()
        print("Passed \(checks) YouTube notification parsing, paging, and navigation checks")
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
