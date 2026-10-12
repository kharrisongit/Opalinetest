import UIKit

/// Lives within the inbox row. Fetching, typing and sending never route through the player.
final class NotificationReplyView: UIView, UITextViewDelegate {
    let composer = InlineCommentComposer()
    private let parentView = CommentContentView()
    private let sentView = CommentContentView()
    private let status = UILabel()
    private let retry = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let stack = UIStackView()
    private let item: YouTubeNotification
    private var generation = 0
    var onResize: (() -> Void)?
    var onClose: (() -> Void)?
    var onConnect: (() -> Void)?

    init(item: YouTubeNotification) {
        self.item = item
        super.init(frame: .zero)
        setup()
        wireComposer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load() {
        guard let videoID = item.destination.videoID,
              let linkedID = item.destination.commentID else { return }
        generation += 1
        let expected = generation
        composer.isHidden = true
        parentView.isHidden = true
        retry.isHidden = true
        status.text = "youtubeInbox.loadingThread".localized
        status.isHidden = false
        YouTubeCommentClient.shared.readThread(
            videoID: videoID, commentID: linkedID
        ) { [weak self] result in
            guard let self, self.generation == expected else {
                return
            }
            self.finish(result, videoID: videoID, linkedID: linkedID)
        }
    }

    func cancel() {
        generation += 1
        endEditing(true)
    }

    private func finish(_ result: Result<[String: Any], Error>, videoID: String, linkedID: String) {
        do {
            let json = try result.get()
            let parent = try resolvedParent(in: json, linkedID: linkedID)
            // Confirm YouTube offers a reply operation for this exact parent before enabling Send.
            _ = try YouTubeCommentModel.writeBody(
                in: json, target: CommentPostTarget(videoID: videoID, parentID: parent.id)
            )
            parentView.configure(parent, linkDelegate: self)
            parentView.isHidden = false
            status.isHidden = true
            composer.isHidden = false
            composer.configure(videoID: videoID)
            composer.beginReply(to: parent)
        } catch {
            status.text = "youtubeInbox.threadUnavailable".localized
            retry.isHidden = false
        }
        onResize?()
    }

    private func resolvedParent(in json: [String: Any], linkedID: String) throws -> Comment {
        guard let parentID = NotificationReplyTarget.parentID(in: json, linkedID: linkedID),
              let page = InnertubeClient.parseCommentsPage(json),
              let parent = page.comments.first(where: { $0.id == parentID }) else {
            throw CommentAPIError(reason: "parentCommentNotFound")
        }
        return parent
    }

    private func wireComposer() {
        composer.onCancelReply = { [weak self] in self?.onClose?() }
        composer.onConnect = { [weak self] in self?.onConnect?() }
        composer.onResize = { [weak self] in self?.onResize?() }
        composer.onBeginEditing = { [weak self] in self?.onResize?() }
        composer.onPosted = { [weak self] comment, target in
            guard let self, self.composer.target.draftKey == target.draftKey else {
                return
            }
            self.sentView.configure(comment, linkDelegate: self, isReply: true)
            self.sentView.isHidden = false
            self.composer.endEditing(true)
            self.onResize?()
        }
    }

    private func setup() {
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 14)
        status.numberOfLines = 0
        status.textColor = ThemeManager.shared.secondaryText
        close.setTitle("common.close".localized, for: .normal)
        close.contentHorizontalAlignment = .trailing
        close.addTarget(self, action: #selector(closeReply), for: .touchUpInside)
        retry.setTitle("youtubeInbox.retry".localized, for: .normal)
        retry.addTarget(self, action: #selector(retryLoad), for: .touchUpInside)
        for child in [close, status, parentView, sentView, retry, composer] {
            stack.addArrangedSubview(child)
        }
        parentView.isHidden = true
        sentView.isHidden = true
        composer.isHidden = true
        retry.isHidden = true
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    @objc
    private func closeReply() { onClose?() }

    @objc
    private func retryLoad() { load() }
}
