import UIKit

final class CommentComposerViewController: UIViewController {
    // Drafts stay on this device, in memory, until posted or the app exits.
    private static var drafts: [String: String] = [:]

    let target: CommentPostTarget
    let editor = UITextView()
    let accountButton = UIButton(type: .system)
    let contextLabel = UILabel()
    let statusLabel = UILabel()
    var bottom: NSLayoutConstraint?
    var isPosting = false
    var onPosted: ((Comment) -> Void)?

    private var draftKey: String { "\(target.videoID):\(target.parentID ?? "")" }

    init(target: CommentPostTarget) {
        self.target = target
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func styleButton(_ button: UIButton) {
        button.backgroundColor = ThemeManager.shared.accent
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.lightGray, for: .disabled)
        button.layer.cornerRadius = 12
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    }

    static func makeWriteButton(target: Any, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("nativeComments.write".localized, for: .normal)
        styleButton(button)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = (target.parentID == nil ? "nativeComments.write" : "nativeComments.reply").localized
        setupLayout()
        setupActions()
        editor.text = Self.drafts[draftKey] ?? ""
        editor.delegate = self
        refreshAccount()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAccount()
    }

    func refreshAccount() {
        let channel = CommentAPIClient.shared.channel
        let title = channel.map { "nativeComments.postingAs".localized(with: $0.title) }
            ?? "nativeComments.connectToPost".localized
        accountButton.setTitle(title, for: .normal)
        updatePostState()
    }

    private func setupActions() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "common.cancel".localized,
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "nativeComments.post".localized,
            style: .done,
            target: self,
            action: #selector(post)
        )
        accountButton.addTarget(self, action: #selector(openAccount), for: .touchUpInside)
    }

    private func updatePostState() {
        let nonempty = !editor.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        navigationItem.rightBarButtonItem?.isEnabled =
            nonempty && CommentAPIClient.shared.channel != nil && !isPosting
        navigationItem.leftBarButtonItem?.isEnabled = !isPosting
        editor.isEditable = !isPosting
        accountButton.isEnabled = !isPosting
        if #available(iOS 13.0, *) {
            isModalInPresentation = isPosting
            navigationController?.isModalInPresentation = isPosting
        }
    }

    @objc
    private func openAccount() {
        editor.resignFirstResponder()
        navigationController?.pushViewController(CommentAccountViewController(), animated: true)
    }

    @objc
    private func cancel() {
        Self.drafts[draftKey] = editor.text
        dismiss(animated: true)
    }

    @objc
    private func post() {
        guard !isPosting, navigationItem.rightBarButtonItem?.isEnabled == true else {
            return
        }
        isPosting = true
        updatePostState()
        editor.resignFirstResponder()
        statusLabel.text = "nativeComments.posting".localized
        CommentAPIClient.shared.post(text: editor.text, target: target) { [weak self] result in
            guard let self else {
                return
            }
            self.isPosting = false
            self.updatePostState()
            switch result {
            case .success(let comment):
                Self.drafts.removeValue(forKey: self.draftKey)
                self.dismiss(animated: true) { self.onPosted?(comment) }
            case .failure(let error):
                self.statusLabel.text = error.localizedDescription
                UIAccessibility.post(
                    notification: .announcement, argument: error.localizedDescription
                )
            }
        }
    }

    @objc
    private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboard = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboard.minY - view.safeAreaInsets.bottom)
        bottom?.constant = -(overlap + 16)
        view.layoutIfNeeded()
    }
}

extension CommentComposerViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        Self.drafts[draftKey] = textView.text
        statusLabel.text = "nativeComments.publicNotice".localized
        updatePostState()
    }
}
