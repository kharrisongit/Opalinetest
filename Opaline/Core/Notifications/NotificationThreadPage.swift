import Foundation

/// Keeps replies and their continuation scoped to the selected thread, not the video feed.
struct NotificationThreadPage {
    let parent: Comment
    let replies: [Comment]
    let continuation: String?

    static func parse(_ json: [String: Any], linkedID: String) throws -> Self {
        guard let parentID = NotificationReplyTarget.parentID(in: json, linkedID: linkedID) else {
            throw CommentAPIError(reason: "parentCommentNotFound")
        }
        let updates = json["frameworkUpdates"] as? [String: Any]
        let batch = updates?["entityBatchUpdate"] as? [String: Any]
        let mutations = batch?["mutations"] as? [[String: Any]] ?? []
        for thread in YouTubeCommentModel.objects(named: "commentThreadRenderer", in: json) {
            guard let parent = InnertubeClient.parseComment(item: thread, mutations: mutations),
                  parent.id == parentID else { continue }
            let replies = thread["replies"] as? [String: Any]
            let renderer = replies?["commentRepliesRenderer"] as? [String: Any]
            let contents = renderer?["contents"] as? [[String: Any]] ?? []
            return Self(
                parent: parent,
                replies: contents.compactMap {
                    InnertubeClient.parseComment(item: $0, mutations: mutations)
                },
                continuation: InnertubeClient.commentsNextContinuation(in: contents)
            )
        }
        throw CommentAPIError(reason: "parentCommentNotFound")
    }
}
