import UIKit

extension WatchViewController {
    func setupCommentWriting() {
        commentComposer.configure(videoID: initialVideo.id)
        commentsPanel.setComposer(commentComposer)
        commentComposer.onPosted = { [weak self] comment, target in
            guard let self, self.initialVideo.id == target.videoID else {
                return
            }
            self.didPostComment(comment, parentID: target.parentID)
        }
        commentComposer.onBeginEditing = { [weak self] in
            self?.expandCommentsForKeyboard()
        }
        commentComposer.onConnect = { [weak self] in
            self?.presentCommentAccount()
        }
    }

    func showCommentComposer(parent: Comment?) {
        commentComposer.configure(videoID: initialVideo.id)
        commentComposer.beginReply(to: parent)
    }

    private func presentCommentAccount() {
        guard presentedViewController == nil else {
            return
        }
        let navigation = RotatingNavigationController(
            rootViewController: CommentAccountViewController()
        )
        navigation.modalPresentationStyle = .formSheet
        present(navigation, animated: true)
    }

    private func didPostComment(_ comment: Comment, parentID: String?) {
        // Insert the server-confirmed resource. A stale read must not replace it.
        commentsLoadGeneration += 1
        isLoadingComments = false
        hasLoadedComments = true
        commentHeightCache = [:]
        for index in commentThreads.indices {
            commentThreads[index].isLoadingReplies = false
        }
        if let parentID,
           let index = commentThreads.firstIndex(where: { $0.comment.id == parentID }) {
            commentThreads[index].replies.append(comment)
            commentThreads[index].isExpanded = true
        } else if parentID == nil {
            commentThreads.insert(CommentThread(comment: comment), at: 0)
            commentsPreview = comment
            commentsTableView.setContentOffset(.zero, animated: false)
        }
        renderComments()
        UIAccessibility.post(
            notification: .announcement, argument: "nativeComments.posted".localized
        )
    }
}
