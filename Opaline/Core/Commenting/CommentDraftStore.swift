import Foundation

struct CommentSubmission {
    let target: CommentPostTarget
    let text: String
}

/// Main-thread owned. An in-flight send belongs to its captured video and thread.
final class CommentDraftStore {
    static let shared = CommentDraftStore()
    static let didChange = Notification.Name("inlineCommentDraftDidChange")
    private var drafts: [String: String] = [:]
    private var sending: Set<String> = []

    func text(for target: CommentPostTarget) -> String {
        drafts[target.draftKey] ?? ""
    }

    func update(_ text: String, for target: CommentPostTarget) {
        guard !isSending(target) else {
            return
        }
        drafts[target.draftKey] = text
    }

    func isSending(_ target: CommentPostTarget) -> Bool {
        sending.contains(target.draftKey)
    }

    func begin(_ target: CommentPostTarget) -> CommentSubmission? {
        let text = text(for: target)
        guard !target.videoID.isEmpty, !isSending(target),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        sending.insert(target.draftKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return CommentSubmission(target: target, text: text)
    }

    func finish(_ submission: CommentSubmission, succeeded: Bool) {
        sending.remove(submission.target.draftKey)
        if succeeded {
            drafts.removeValue(forKey: submission.target.draftKey)
        }
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}

extension CommentPostTarget {
    var draftKey: String { "\(videoID):\(parentID ?? "")" }
}
