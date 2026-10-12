import Foundation

/// Resolve only a server-returned thread containing the notification's linked comment.
/// Never infer a parent from an ID prefix or pick an unrelated first comment.
enum NotificationReplyTarget {
    static func parentID(in page: [String: Any], linkedID: String) -> String? {
        guard !linkedID.isEmpty else {
            return nil
        }
        let threads = YouTubeCommentModel.objects(named: "commentThreadRenderer", in: page)
        let matches = threads.compactMap { thread -> String? in
            let root = thread["commentViewModel"] ?? thread["comment"] ?? [:]
            guard let parent = identifiers(in: root).first,
                  identifiers(in: thread).contains(linkedID) else { return nil }
            return parent
        }
        let parents = Set(matches)
        if parents.count == 1 {
            return parents.first
        }
        if !parents.isEmpty {
            return nil
        }
        let entities = YouTubeCommentModel.objects(named: "commentEntityPayload", in: page)
        let explicit = entities.compactMap { entity -> String? in
            let properties = entity["properties"] as? [String: Any]
            guard properties?["commentId"] as? String == linkedID else {
                return nil
            }
            return properties?["parentCommentId"] as? String
        }
        let explicitParents = Set(explicit.filter { !$0.isEmpty })
        return explicitParents.count == 1 ? explicitParents.first : nil
    }

    private static func identifiers(in value: Any) -> [String] {
        if let array = value as? [Any] {
            return array.flatMap { identifiers(in: $0) }
        }
        guard let object = value as? [String: Any] else {
            return []
        }
        let own = (object["commentId"] as? String).map { [$0] } ?? []
        return own + object.keys.sorted().flatMap { key in
            object[key].map { identifiers(in: $0) } ?? []
        }
    }
}
