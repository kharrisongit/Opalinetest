import Foundation

enum YouTubeCommentModel {
    /// This traversal finds a named renderer, never a paging continuation.
    static func objects(named key: String, in value: Any) -> [[String: Any]] {
        if let array = value as? [Any] {
            return array.flatMap { objects(named: key, in: $0) }
        }
        guard let object = value as? [String: Any] else {
            return []
        }
        if let match = object[key] as? [String: Any] {
            return [match]
        }
        return object.keys.sorted().flatMap { name in
            object[name].map { objects(named: key, in: $0) } ?? []
        }
    }

    static func text(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else {
            return value as? String
        }
        if let simple = object["simpleText"] as? String ?? object["content"] as? String {
            return simple
        }
        let runs = object["runs"] as? [[String: Any]] ?? []
        let text = runs.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    static func account(_ json: [String: Any]) throws -> CommentAPIChannel {
        guard let header = objects(named: "activeAccountHeaderRenderer", in: json).first,
              let title = text(header["channelHandle"]) ?? text(header["accountName"]),
              !title.isEmpty else {
            throw CommentAPIError(reason: "signedOut")
        }
        return CommentAPIChannel(id: "website-session", title: title)
    }

    static func writeBody(
        in page: [String: Any], target: CommentPostTarget
    ) throws -> [String: Any] {
        let scope: Any
        if let parentID = target.parentID {
            scope = try replyToolbar(in: page, parentID: parentID)
        } else {
            guard let header = objects(named: "commentsHeaderRenderer", in: page).first else {
                throw CommentAPIError(reason: "commentsDisabled")
            }
            scope = header["createRenderer"] ?? [:]
        }
        let key = target.parentID == nil ? "createCommentEndpoint" : "createCommentReplyEndpoint"
        guard let endpoint = objects(named: key, in: scope).first else {
            throw CommentAPIError(reason: "operationNotSupported")
        }
        let parameter = target.parentID == nil ? "createCommentParams" : "createReplyParams"
        guard let params = endpoint[parameter] as? String, !params.isEmpty else {
            throw CommentAPIError(reason: "operationNotSupported")
        }
        // Never execute arbitrary commands or challenge/account-creation actions from a response.
        return [parameter: params]
    }

    private static func replyToolbar(in page: [String: Any], parentID: String) throws -> Any {
        let views = objects(named: "commentViewModel", in: page).map {
            $0["commentViewModel"] as? [String: Any] ?? $0
        }
        guard let view = views.first(where: { $0["commentId"] as? String == parentID }),
              let key = view["toolbarSurfaceKey"] as? String else {
            throw CommentAPIError(reason: "parentCommentNotFound")
        }
        let updates = page["frameworkUpdates"] as? [String: Any]
        let batch = updates?["entityBatchUpdate"] as? [String: Any]
        let mutations = batch?["mutations"] as? [[String: Any]] ?? []
        guard let mutation = mutations.first(where: { $0["entityKey"] as? String == key }) else {
            throw CommentAPIError(reason: "operationNotSupported")
        }
        return mutation
    }

    static func createdComment(_ json: [String: Any]) throws -> Comment {
        let actionResult = json["actionResult"] as? String
        guard json["error"] == nil,
              actionResult == nil || actionResult == "ACTION_RESULT_SUCCESS" else {
            throw CommentAPIError(reason: "uncertain")
        }
        // A successful write must include the created resource, not an optimistic local copy.
        let entities = objects(named: "commentEntityPayload", in: json)
        guard entities.count == 1, let entity = entities.first,
              let properties = entity["properties"] as? [String: Any],
              let id = properties["commentId"] as? String, !id.isEmpty,
              let content = text(properties["content"]) else {
            return try legacyCreatedComment(json)
        }
        let author = entity["author"] as? [String: Any] ?? [:]
        return Comment(
            id: id,
            authorName: author["displayName"] as? String ?? "",
            authorChannelId: author["channelId"] as? String,
            authorAvatarURL: author["avatarThumbnailUrl"] as? String,
            content: content,
            publishedTime: "nativeComments.justNow".localized,
            likeCount: nil,
            replyCount: nil,
            isPinned: false,
            replyContinuation: nil
        )
    }

    private static func legacyCreatedComment(_ json: [String: Any]) throws -> Comment {
        let renderers = objects(named: "commentRenderer", in: json)
        guard renderers.count == 1, let comment = renderers.first,
              let id = comment["commentId"] as? String, !id.isEmpty,
              let content = text(comment["contentText"]) else {
            throw CommentAPIError(reason: "uncertain")
        }
        return Comment(
            id: id,
            authorName: text(comment["authorText"]) ?? "",
            authorChannelId: nil,
            authorAvatarURL: nil,
            content: content,
            publishedTime: "nativeComments.justNow".localized,
            likeCount: nil,
            replyCount: nil,
            isPinned: false,
            replyContinuation: nil
        )
    }
}
