import UIKit

final class CommentAccountViewController: UIViewController {
    private let status = UILabel()
    private let connectButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "nativeComments.account".localized
        setup()
        if navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "common.close".localized,
                style: .plain,
                target: self,
                action: #selector(close)
            )
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let channel = CommentPostingService.channel
        status.text = channel.map { "nativeComments.postingAs".localized(with: $0.title) }
            ?? "nativeComments.webExplanation".localized
        disconnectButton.isHidden = channel == nil
    }

    private func setup() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .body)
        status.textColor = theme.primaryText
        connectButton.setTitle("nativeComments.webConnect".localized, for: .normal)
        connectButton.addTarget(self, action: #selector(connect), for: .touchUpInside)
        CommentControlStyle.apply(connectButton)
        disconnectButton.setTitle("nativeComments.disconnect".localized, for: .normal)
        disconnectButton.tintColor = theme.accent
        disconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)
        let privacy = UILabel()
        privacy.text = "nativeComments.webPrivacy".localized
        privacy.numberOfLines = 0
        privacy.font = .preferredFont(forTextStyle: .subheadline)
        privacy.textColor = theme.secondaryText
        for item in [status, connectButton, disconnectButton, privacy] {
            stack.addArrangedSubview(item)
        }
        installScrollContent(stack)
    }

    private func installScrollContent(_ stack: UIStackView) {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20
            ),
            stack.trailingAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20
            ),
            stack.bottomAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24
            ),
            stack.widthAnchor.constraint(
                equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40
            )
        ])
    }

    @objc
    private func connect() {
        navigationController?.pushViewController(YouTubeCommentSignIn(), animated: true)
    }

    @objc
    private func disconnect() {
        YouTubeCommentClient.shared.disconnect()
        CommentAPIClient.shared.disconnect()
        status.text = "nativeComments.webExplanation".localized
        disconnectButton.isHidden = true
    }

    @objc
    private func close() {
        dismiss(animated: true)
    }
}
