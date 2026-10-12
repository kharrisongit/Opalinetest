import UIKit

// MARK: - Collapsed comments preview

extension WatchViewController {
    /// The official app skips the pinned comment in the preview — it isn't
    /// necessarily the conversation's top comment. `Comment` only parses
    /// `isPinned` (see `InnertubeClient+CommentBuilding.assembleComment`),
    /// not channel-owner authorship, so that half of the reference rule
    /// can't be implemented without touching `Core/API`. Falls back to the
    /// first comment if everything happens to be pinned.
    private var previewComment: Comment? {
        let first = commentThreads.first { !$0.comment.isPinned }
            ?? commentThreads.first
        return first?.comment
    }

    /// Shows exactly one row: a skeleton while the first page is in flight,
    /// an empty message once it's known there is nothing, or one real
    /// comment — reusing the single shared `commentPreviewContentView`
    /// rather than building a new view.
    ///
    /// Stays visible while the panel is open: everything under the player
    /// keeps its place and the panel simply slides over it.
    func updateCommentsPreview() {
        commentsStackView.arrangedSubviews.forEach {
            commentsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        if commentsPreview == nil {
            commentsPreview = previewComment
        }
        guard let preview = commentsPreview else {
            if hasLoadedComments, !isLoadingComments {
                renderPreviewEmptyMessage()
            } else {
                renderPreviewSkeleton()
            }
            return
        }
        commentPreviewContentView.configure(preview, linkDelegate: self)
        commentsStackView.addArrangedSubview(commentPreviewContentView)
    }

    private func renderPreviewSkeleton() {
        let row = UIView()
        row.layer.cornerRadius = 8
        row.layer.masksToBounds = true
        row.heightAnchor.constraint(
            equalToConstant: 56
        ).isActive = true
        commentsStackView.addArrangedSubview(row)
        // The shimmer overlay is frame-based, so the row needs its size
        // before it is added.
        commentsStackView.layoutIfNeeded()
        row.showSkeleton()
    }

    private func renderPreviewEmptyMessage() {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = ThemeManager.shared.secondaryText
        label.text = "player.comments.unavailableYet".localized
        commentsStackView.addArrangedSubview(label)
    }
}
