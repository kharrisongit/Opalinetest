import Foundation

struct Comment: Codable {
    let id: String
    let authorName: String
    let authorChannelId: String?
    let authorAvatarURL: String?
    let content: String
    let publishedTime: String?
    let likeCount: String?
    let replyCount: String?
    let isPinned: Bool
    /// Token that loads this thread's replies, `nil` when it has none.
    /// Replies are one level deep on YouTube — a reply never carries one.
    let replyContinuation: String?
}

struct CommentsPage: Codable {
    let title: String?
    let comments: [Comment]
    let continuation: String?
    /// "Top" / "Newest", straight from the header's sort menu — the server
    /// sends both the localized title and a ready continuation token, so
    /// nothing has to be built or translated here. Only the first page of a
    /// sort order carries them.
    let sortOptions: [CommentSortOption]
}

struct CommentSortOption: Codable {
    let title: String
    let token: String
    let isSelected: Bool
}
