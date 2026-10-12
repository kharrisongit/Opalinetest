import SafariServices
import UIKit

extension WatchViewController: SFSafariViewControllerDelegate {
    func setupCommentWriting() {
        let button = YouTubeCommentsBrowser.makeButton(
            target: self, action: #selector(writeComment)
        )
        commentsPanel.setHeaderButtons([button])
    }

    @objc
    private func writeComment() {
        guard presentedViewController == nil,
              let browser = YouTubeCommentsBrowser.make(
                  videoId: initialVideo.id, delegate: self
              ) else {
            return
        }
        videoPlayerView?.player?.pause()
        present(browser, animated: true)
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // Safari cannot tell us whether a comment was submitted. Refresh
        // without claiming success, and leave playback paused for the user.
        let sortToken = commentSortOptions.first(where: \.isSelected)?.token
        commentsLoadGeneration += 1
        isLoadingComments = false
        commentThreads = []
        commentHeightCache = [:]
        commentsContinuation = nil
        commentsPreview = nil
        commentsTableView.setContentOffset(.zero, animated: false)
        loadComments(continuation: sortToken, isReload: true)
    }
}
