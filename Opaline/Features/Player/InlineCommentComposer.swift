import UIKit

final class InlineCommentComposer: UIView {
    let editor = UITextView()
    let placeholder = UILabel()
    let sendButton = UIButton(type: .system)
    let accountButton = UIButton(type: .system)
    let cancelReplyButton = UIButton(type: .system)
    let status = UILabel()
    let replyLabel = UILabel()
    let replyRow = UIStackView()
    var editorHeight: NSLayoutConstraint?
    var target = CommentPostTarget(videoID: "")
    var onPosted: ((Comment, CommentPostTarget) -> Void)?
    var onConnect: (() -> Void)?
    var onBeginEditing: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        editor.delegate = self
        sendButton.addTarget(self, action: #selector(sendComment), for: .touchUpInside)
        accountButton.addTarget(self, action: #selector(connect), for: .touchUpInside)
        cancelReplyButton.addTarget(self, action: #selector(cancelReply), for: .touchUpInside)
        for name in [CommentAPIClient.didChange, YouTubeCommentClient.didChange] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(refreshAccount), name: name, object: nil
            )
        }
        refreshAccount()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(videoID: String) {
        guard target.videoID != videoID else {
            return
        }
        endEditing(true)
        target = CommentPostTarget(videoID: videoID)
        loadDraft()
    }

    func beginReply(to parent: Comment?) {
        target = CommentPostTarget(
            videoID: target.videoID, parentID: parent?.id, parentAuthor: parent?.authorName
        )
        loadDraft()
        editor.becomeFirstResponder()
    }

    func loadDraft() {
        editor.text = CommentDraftStore.shared.text(for: target)
        replyRow.isHidden = target.parentID == nil
        replyLabel.text = "nativeComments.replyingTo".localized(with: target.parentAuthor ?? "")
        status.text = nil
        refreshAccount()
        resizeEditor()
    }

    @objc
    func refreshAccount() {
        let channel = CommentPostingService.channel
        accountButton.setTitle(
            channel.map { "nativeComments.postingAs".localized(with: $0.title) }
                ?? "nativeComments.webConnect".localized,
            for: .normal
        )
        updateControls()
    }

    func updateControls() {
        let sending = CommentDraftStore.shared.isSending(target)
        let nonempty = !editor.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = nonempty && CommentPostingService.channel != nil && !sending
        sendButton.alpha = sendButton.isEnabled ? 1 : 0.45
        editor.isEditable = !sending
        placeholder.isHidden = !editor.text.isEmpty
        accountButton.isEnabled = !sending
        status.isHidden = status.text?.isEmpty != false
        sendButton.setTitle(
            (sending ? "nativeComments.posting" : "nativeComments.send").localized, for: .normal
        )
    }

    func resizeEditor() {
        let height = editor.sizeThatFits(CGSize(width: max(100, editor.bounds.width), height: 120))
        editorHeight?.constant = min(100, max(44, height.height))
    }

    @objc
    private func connect() {
        endEditing(true)
        onConnect?()
    }

    @objc
    private func cancelReply() {
        beginReply(to: nil)
    }

    @objc
    private func sendComment() {
        guard CommentPostingService.channel != nil,
              let submission = CommentDraftStore.shared.begin(target) else {
            return
        }
        status.text = "nativeComments.posting".localized
        updateControls()
        CommentPostingService.post(submission) { [weak self] result in
            let succeeded = (try? result.get()) != nil
            CommentDraftStore.shared.finish(submission, succeeded: succeeded)
            self?.finish(result, submission: submission)
        }
    }

    private func finish(_ result: Result<Comment, Error>, submission: CommentSubmission) {
        let message: String
        switch result {
        case .success(let comment):
            onPosted?(comment, submission.target)
            message = "nativeComments.posted".localized
        case .failure(let error):
            message = error.localizedDescription
        }
        if target.draftKey == submission.target.draftKey {
            editor.text = CommentDraftStore.shared.text(for: target)
            status.text = message
            updateControls()
            resizeEditor()
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

extension InlineCommentComposer: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        onBeginEditing?()
    }

    func textViewDidChange(_ textView: UITextView) {
        CommentDraftStore.shared.update(textView.text, for: target)
        status.text = nil
        updateControls()
        resizeEditor()
    }
}
