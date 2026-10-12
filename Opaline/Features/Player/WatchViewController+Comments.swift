import UIKit

// MARK: - Comments (network + preview)

extension WatchViewController {
    func resetComments() {
        commentsLoadGeneration += 1
        commentThreads = []
        commentSortOptions = []
        commentsPanel.setSortOptions([])
        commentsContinuation = nil
        commentsPreview = nil
        isLoadingComments = false
        hasLoadedComments = false
        collapseComments()
        setCommentsTitle("player.comments.title".localized)
        renderComments()
    }

    func loadComments(continuation: String? = nil, isReload: Bool = false) {
        guard !isLoadingComments else {
            return
        }
        isLoadingComments = true
        // Only the very first load has no count to show yet; a sort switch
        // empties the list too, and blanking the header to "Loading" there
        // made the count flicker for the duration of one request.
        if commentThreads.isEmpty, !hasLoadedComments {
            commentsLabel.text = "player.comments.loading".localized
        }
        renderComments()
        let generation = commentsLoadGeneration
        client.fetchComments(
            videoId: initialVideo.id,
            continuation: continuation,
            cancellationToken: pageLoadToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.commentsLoadGeneration == generation else {
                    return
                }
                self.handleCommentsResult(
                    result,
                    isReload: isReload || continuation == nil
                )
            }
        }
    }

    /// Re-fetches the list in another order. The sort tokens come from the
    /// server's own menu, so switching is just a reload with a different
    /// first-page token.
    func selectCommentSort(at index: Int) {
        guard let option = commentSortOptions[safe: index],
              !option.isSelected
        else {
            return
        }
        commentSortOptions = commentSortOptions.enumerated().map {
            CommentSortOption(
                title: $1.title, token: $1.token, isSelected: $0 == index
            )
        }
        commentThreads = []
        commentsLoadGeneration += 1
        commentHeightCache = [:]
        commentsContinuation = nil
        isLoadingComments = false
        commentsTableView.setContentOffset(.zero, animated: false)
        loadComments(continuation: option.token, isReload: true)
    }

    func handleCommentsResult(
        _ result: Result<CommentsPage, Error>,
        isReload: Bool
    ) {
        isLoadingComments = false
        let isFirstLoad = !hasLoadedComments
        hasLoadedComments = true
        switch result {
        case .failure(let error):
            AppLog.player(
                "comments load failed "
                + "\(initialVideo.id): \(error)"
            )
            // Dropping the token stops an endless retry loop at the tail of
            // a list whose next page keeps failing.
            commentsContinuation = nil
            if commentThreads.isEmpty {
                commentsLabel.text =
                    "player.comments.unavailable".localized
            }
        case .success(let page):
            applyCommentsPage(
                page, isReload: isReload, isFirstLoad: isFirstLoad
            )
        }
        renderComments()
    }

    private func applyCommentsPage(
        _ page: CommentsPage,
        isReload: Bool,
        isFirstLoad: Bool
    ) {
        commentsContinuation = page.continuation
        if isReload {
            commentThreads = page.comments.map(CommentThread.init)
        } else {
            appendNewComments(page.comments)
        }
        if !page.sortOptions.isEmpty {
            commentSortOptions = page.sortOptions
            commentsPanel.setSortOptions(page.sortOptions)
        }
        // Only the first page carries the server's total ("546 Comments");
        // continuations come back without one. Falling back to the loaded
        // count there rewrote the header down to 29 — and on a sort reload
        // it rewrote a known total with a partial one.
        if let title = page.title {
            setCommentsTitle(title)
        } else if isReload, isFirstLoad {
            setCommentsTitle(
                "player.comments.titleCount"
                    .localized(with: commentThreads.count)
            )
        }
    }

    /// The in-flow section header and the panel's own header show the same
    /// text — kept in sync here rather than duplicating state.
    private func setCommentsTitle(_ text: String) {
        commentsLabel.text = text
        commentsPanel.titleLabel.text = text
    }

    func appendNewComments(_ newComments: [Comment]) {
        let existingIds = Set(commentThreads.map(\.comment.id))
        commentThreads.append(contentsOf: newComments
            .filter { !existingIds.contains($0.id) }
            .map(CommentThread.init))
    }

    // MARK: - Replies

    /// Expands or collapses a thread; the first expansion pulls its replies.
    func toggleReplies(at index: Int) {
        guard commentThreads.indices.contains(index) else {
            return
        }
        commentThreads[index].isExpanded.toggle()
        if commentThreads[index].isExpanded,
           commentThreads[index].replies.isEmpty {
            loadReplies(at: index)
        } else {
            renderComments()
        }
    }

    func loadReplies(at index: Int) {
        guard commentThreads.indices.contains(index),
              !commentThreads[index].isLoadingReplies,
              let token = commentThreads[index].repliesContinuation
        else {
            return
        }
        commentThreads[index].isLoadingReplies = true
        renderComments()
        let generation = commentsLoadGeneration
        client.fetchComments(
            videoId: initialVideo.id,
            continuation: token,
            cancellationToken: pageLoadToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.commentsLoadGeneration == generation else {
                    return
                }
                self.handleRepliesResult(result, at: index)
            }
        }
    }

    private func handleRepliesResult(
        _ result: Result<CommentsPage, Error>,
        at index: Int
    ) {
        guard commentThreads.indices.contains(index) else {
            return
        }
        commentThreads[index].isLoadingReplies = false
        switch result {
        case .failure(let error):
            AppLog.player("replies load failed: \(error)")
            commentThreads[index].repliesContinuation = nil
        case .success(let page):
            let existing = Set(commentThreads[index].replies.map(\.id))
            commentThreads[index].replies.append(
                contentsOf: page.comments.filter {
                    !existing.contains($0.id)
                }
            )
            commentThreads[index].repliesContinuation = page.continuation
        }
        renderComments()
    }

    // MARK: - Rendering

    /// Refreshes both surfaces that can show comments: the always-present
    /// one-row preview, and the expanded table (cheap to reload even while
    /// hidden — only visible rows are ever instantiated).
    func renderComments() {
        commentRows = buildCommentRows()
        updateCommentsPreview()
        commentsTableView.reloadData()
        view.setNeedsLayout()
    }

    private func buildCommentRows() -> [CommentRow] {
        guard !commentThreads.isEmpty else {
            let isDone = hasLoadedComments && !isLoadingComments
            let empty = "player.comments.unavailableYet".localized
            return [.status(isDone ? empty : nil)]
        }
        var rows = commentThreads.commentRows()
        if isLoadingComments || commentsContinuation != nil {
            rows.append(.status("player.comments.loading".localized))
        }
        return rows
    }

    func expandRelatedIfNeeded() {
        guard visibleRelatedVideos.count
                < allRelatedVideos.count else {
            return
        }
        let nextCount = min(
            visibleRelatedVideos.count + WatchPaging.relatedBatch,
            allRelatedVideos.count
        )
        visibleRelatedVideos = Array(
            allRelatedVideos.prefix(nextCount)
        )
        relatedCollectionView.reloadData()
        view.setNeedsLayout()
    }
}
