import UIKit

final class CommentAccountViewController: UIViewController {
    private let clientField = UITextField()
    private let status = UILabel()
    private let connectButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    private var isBusy = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "nativeComments.account".localized
        setup()
        refresh()
    }

    private func setup() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        let help = makeLabel("nativeComments.setupHelp".localized)
        let bundle = makeLabel("nativeComments.bundleID".localized(
            with: Bundle.main.bundleIdentifier ?? "com.verback.YTLite"
        ))
        let caption = makeLabel("nativeComments.clientID".localized)
        let privacy = makeLabel("nativeComments.privacy".localized)
        setupField()
        status.numberOfLines = 0
        status.textColor = theme.primaryText
        connectButton.setTitle("nativeComments.connect".localized, for: .normal)
        connectButton.addTarget(self, action: #selector(connect), for: .touchUpInside)
        CommentComposerViewController.styleButton(connectButton)
        disconnectButton.setTitle("nativeComments.disconnect".localized, for: .normal)
        disconnectButton.tintColor = theme.accent
        disconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)
        let items = [
            status, help, bundle, caption, clientField,
            connectButton, disconnectButton, privacy
        ]
        for item in items {
            stack.addArrangedSubview(item)
        }
        installScrollContent(stack)
    }

    private func setupField() {
        clientField.text = CommentAPIClient.shared.clientID
        clientField.placeholder = "123…apps.googleusercontent.com"
        clientField.borderStyle = .roundedRect
        clientField.autocapitalizationType = .none
        clientField.autocorrectionType = .no
        clientField.keyboardType = .URL
        clientField.textColor = ThemeManager.shared.primaryText
        clientField.backgroundColor = ThemeManager.shared.surface
        clientField.accessibilityLabel = "nativeComments.clientID".localized
        clientField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }

    private func installScrollContent(_ stack: UIStackView) {
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
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

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = ThemeManager.shared.secondaryText
        return label
    }

    private func refresh() {
        if let channel = CommentAPIClient.shared.channel {
            status.text = "nativeComments.postingAs".localized(with: channel.title)
        } else {
            status.text = "nativeComments.notConnected".localized
        }
        connectButton.isEnabled = !isBusy
        clientField.isEnabled = !isBusy
        disconnectButton.isEnabled = !isBusy
        disconnectButton.isHidden = CommentAPIClient.shared.channel == nil
    }

    @objc
    private func connect() {
        guard !isBusy else {
            return
        }
        view.endEditing(true)
        do {
            try CommentAPIClient.shared.configure(clientID: clientField.text ?? "")
            isBusy = true
            refresh()
            status.text = "nativeComments.connecting".localized
            CommentAPIClient.shared.signIn(from: self) { [weak self] result in
                guard let self else {
                    return
                }
                self.isBusy = false
                self.refresh()
                if case .failure(let error) = result {
                    self.status.text = error.localizedDescription
                }
            }
        } catch {
            status.text = error.localizedDescription
        }
    }

    @objc
    private func disconnect() {
        CommentAPIClient.shared.disconnect()
        refresh()
    }
}
