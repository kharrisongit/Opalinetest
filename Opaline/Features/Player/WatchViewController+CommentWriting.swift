import UIKit

extension WatchViewController {
    func setupCommentWriting() {
        let button = CommentComposerViewController.makeWriteButton(
            target: self, action: #selector(writeComment)
        )
        commentsPanel.setHeaderButtons([button])
    }

    @objc
    private func writeComment() {
        showCommentComposer(parent: nil)
    }

    func showCommentComposer(parent: Comment?) {
        guard presentedViewController == nil else {
            return
        }
        let videoID = initialVideo.id
        let target = CommentPostTarget(
            videoID: videoID, parentID: parent?.id, parentAuthor: parent?.authorName
        )
        let composer = CommentComposerViewController(target: target)
        composer.onPosted = { [weak self] comment in
            guard let self, self.initialVideo.id == videoID else {
                return
            }
            self.didPostComment(comment, parentID: parent?.id)
        }
        let navigation = RotatingNavigationController(rootViewController: composer)
        navigation.modalPresentationStyle = .fullScreen
        videoPlayerView?.multitaskPause.lastUserPause = CACurrentMediaTime()
        videoPlayerView?.player?.pause()
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
