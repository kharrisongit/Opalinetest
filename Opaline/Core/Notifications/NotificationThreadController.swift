import UIKit

/// A comments-only destination. This controller never opens, seeks, or replaces the player.
final class NotificationThreadController: UIViewController {
    let item: YouTubeNotification
    let table = UITableView()
    let composer = InlineCommentComposer()
    let contentStack = UIStackView()
    let message = UILabel()
    let more = UIButton(type: .system)
    var parent: Comment?
    var replies: [Comment] = []
    var continuation: String?
    var usedTokens = Set<String>()
    var loading = false
    var generation = 0
    var keyboardGuide: CommentKeyboardGuide?
    var focusReply: Bool
    var didRevealLinked = false

    init(item: YouTubeNotification, focusReply: Bool) {
        self.item = item
        self.focusReply = focusReply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "youtubeInbox.thread".localized
        setupViews()
        setupComposer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: YouTubeCommentClient.didChange,
            object: nil
        )
        load()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        keyboardGuide?.update()
    }

    @objc
    func accountChanged() {
        generation += 1
        loading = false
        didRevealLinked = false
        parent = nil
        replies = []
        continuation = nil
        setComposerVisible(false)
        table.reloadData()
        load()
    }

    func load() {
        guard !loading else {
            return
        }
        guard let videoID = item.destination.videoID,
              let linkedID = item.destination.commentID else {
            showMessage(item.message + "\n\n" + "youtubeInbox.noThread".localized)
            more.isHidden = true
            return
        }
        loading = true
        more.isEnabled = false
        showMessage("youtubeInbox.loadingThread".localized)
        let expected = generation
        YouTubeCommentClient.shared.readThread(
            videoID: videoID, commentID: linkedID
        ) { [weak self] result in
            guard let self, self.generation == expected else {
                return
            }
            self.loading = false
            self.more.isEnabled = true
            self.finishLoad(result, videoID: videoID)
        }
    }

    private func finishLoad(_ result: Result<[String: Any], Error>, videoID: String) {
        do {
            let json = try result.get()
            guard let linkedID = item.destination.commentID else {
                throw CommentAPIError(reason: "parentCommentNotFound")
            }
            let page = try NotificationThreadPage.parse(json, linkedID: linkedID)
            parent = page.parent
            replies = page.replies
            continuation = page.continuation
            usedTokens = []
            table.backgroundView = nil
            configureReply(json: json, videoID: videoID)
            updateRows()
            if !revealLinked(), continuation != nil { loadMore() }
        } catch {
            showMessage("youtubeInbox.threadUnavailable".localized)
            more.setTitle("youtubeInbox.retry".localized, for: .normal)
            more.isHidden = false
        }
    }

    private func configureReply(json: [String: Any], videoID: String) {
        guard let parent else {
            return
        }
        let target = CommentPostTarget(videoID: videoID, parentID: parent.id)
        setComposerVisible((try? YouTubeCommentModel.writeBody(in: json, target: target)) != nil)
        composer.configure(videoID: videoID)
        let recipient = replies.first { $0.id == item.destination.commentID } ?? parent
        composer.beginReply(to: parent, recipient: recipient, focus: false)
    }

    @objc
    func loadMore() {
        guard parent != nil else {
            load()
            return
        }
        guard !loading, let token = continuation else {
            return
        }
        loading = true
        more.isEnabled = false
        let expected = generation
        YouTubeCommentClient.shared.readComments(continuation: token) { [weak self] result in
            guard let self, self.generation == expected else {
                return
            }
            self.loading = false
            self.more.isEnabled = true
            self.finishReplies(result, token: token)
        }
    }

    private func finishReplies(_ result: Result<[String: Any], Error>, token: String) {
        do {
            let json = try result.get()
            guard let page = InnertubeClient.parseCommentsPage(json) else {
                throw CommentAPIError(reason: "response")
            }
            usedTokens.insert(token)
            var seen = Set(replies.map(\.id))
            replies.append(contentsOf: page.comments.filter {
                $0.id != parent?.id && seen.insert($0.id).inserted
            })
            continuation = page.continuation.flatMap { usedTokens.contains($0) ? nil : $0 }
            updateRows()
            _ = revealLinked()
        } catch {
            more.setTitle("youtubeInbox.retry".localized, for: .normal)
        }
    }

    @discardableResult
    func revealLinked() -> Bool {
        guard !didRevealLinked, let parent else {
            return didRevealLinked
        }
        let comments = [parent] + replies
        guard let index = comments.firstIndex(where: { $0.id == item.destination.commentID })
        else {
            return false
        }
        didRevealLinked = true
        table.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
        if focusReply, !composer.isHidden {
            composer.beginReply(to: parent, recipient: comments[index])
            focusReply = false
        }
        return true
    }

    func updateRows() {
        more.setTitle("youtubeInbox.moreReplies".localized, for: .normal)
        more.isHidden = continuation == nil
        table.reloadData()
        table.layoutIfNeeded()
    }

    func showMessage(_ text: String) {
        message.text = text
        table.backgroundView = message
    }
}
