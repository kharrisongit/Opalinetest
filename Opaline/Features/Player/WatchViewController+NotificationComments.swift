import UIKit

extension WatchViewController {
    func showNotificationComments(commentID: String?) {
        pendingNotificationComment = (initialVideo.id, commentID)
        if sideEffectsStartedForVideoId == initialVideo.id {
            resetComments()
            loadInitialComments()
        }
    }

    func loadInitialComments() {
        guard let pending = pendingNotificationComment, pending.videoID == initialVideo.id else {
            pendingNotificationComment = nil
            loadComments()
            return
        }
        pendingNotificationComment = nil
        let token = pending.commentID.map {
            InnertubeClient.buildCommentsContinuation(
                videoId: initialVideo.id, sortBy: 0, commentId: $0
            )
        }
        loadComments(continuation: token, isReload: true)
        expandComments()
    }
}
