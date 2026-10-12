import Foundation

struct CommentAPIError: LocalizedError {
    let reason: String

    var errorDescription: String? {
        let known = [
            "setup", "signedOut", "noChannel", "callback", "scope", "response",
            "storage", "cancelled", "busy", "uncertain", "network",
            "commentsDisabled", "commentTextTooLong", "commentTextRequired",
            "videoNotFound", "parentCommentNotFound", "operationNotSupported",
            "quotaExceeded", "dailyLimitExceeded", "accessNotConfigured",
            "ineligibleAccount", "forbidden", "invalid_grant"
        ]
        let key = known.contains(reason) ? reason : "generic"
        return "nativeComments.error.\(key)".localized
    }
}

struct CommentAPITokens: Codable {
    let clientID: String
    let accessToken: String
    let refreshToken: String
    let expires: Date
}

struct CommentAPIChannel: Codable {
    let id: String
    let title: String
}

struct CommentAPIAccount: Codable {
    var tokens: CommentAPITokens
    let channel: CommentAPIChannel
}

struct CommentPostTarget {
    let videoID: String
    var parentID: String?
    var parentAuthor: String?

    var endpoint: String { parentID == nil ? "commentThreads" : "comments" }

    func body(text: String, channelID: String?) throws -> [String: Any] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommentAPIError(reason: "commentTextRequired")
        }
        if let parentID {
            return ["snippet": ["parentId": parentID, "textOriginal": text]]
        }
        guard let channelID, !channelID.isEmpty, !videoID.isEmpty else {
            throw CommentAPIError(reason: "videoNotFound")
        }
        return [
            "snippet": [
                "channelId": channelID,
                "videoId": videoID,
                "topLevelComment": ["snippet": ["textOriginal": text]]
            ]
        ]
    }
}

enum CommentAPIModel {
    static func tokens(
        _ json: [String: Any],
        clientID: String,
        previous: CommentAPITokens? = nil
    ) throws -> CommentAPITokens {
        let scopes = (json["scope"] as? String)?.split(separator: " ").map(String.init)
        guard scopes?.contains(CommentOAuthRequest.scope) ?? (previous != nil) else {
            throw CommentAPIError(reason: "scope")
        }
        guard let access = json["access_token"] as? String, !access.isEmpty,
              let duration = json["expires_in"] as? Double,
              duration.isFinite, duration > 0,
              let refresh = json["refresh_token"] as? String ?? previous?.refreshToken,
              !refresh.isEmpty
        else {
            throw CommentAPIError(reason: "response")
        }
        return CommentAPITokens(
            clientID: clientID,
            accessToken: access,
            refreshToken: refresh,
            expires: Date().addingTimeInterval(duration)
        )
    }

    static func json(
        data: Data, status: Int, isCommentWrite: Bool = false
    ) throws -> [String: Any] {
        if isCommentWrite, status >= 500 {
            throw CommentAPIError(reason: "uncertain")
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200 ... 299).contains(status) else {
            if status == 401 {
                throw CommentAPIError(reason: "signedOut")
            }
            let error = json["error"] as? [String: Any]
            let details = error?["errors"] as? [[String: Any]]
            let reason = details?.first?["reason"] as? String
                ?? json["error"] as? String ?? "generic"
            throw CommentAPIError(reason: reason)
        }
        guard !json.isEmpty else {
            throw CommentAPIError(reason: isCommentWrite ? "uncertain" : "response")
        }
        return json
    }

    static func createdComment(_ json: [String: Any], isReply: Bool) throws -> Comment {
        let threadSnippet = json["snippet"] as? [String: Any]
        let resource = isReply ? json : threadSnippet?["topLevelComment"] as? [String: Any]
        guard let resource, let id = resource["id"] as? String, !id.isEmpty,
              let snippet = resource["snippet"] as? [String: Any],
              let text = snippet["textOriginal"] as? String
        else {
            throw CommentAPIError(reason: "uncertain")
        }
        let channel = snippet["authorChannelId"] as? [String: Any]
        return Comment(
            id: id,
            authorName: snippet["authorDisplayName"] as? String ?? "",
            authorChannelId: channel?["value"] as? String,
            authorAvatarURL: snippet["authorProfileImageUrl"] as? String,
            content: text,
            publishedTime: "nativeComments.justNow".localized,
            likeCount: nil,
            replyCount: nil,
            isPinned: false,
            replyContinuation: nil
        )
    }
}
