import UIKit

extension CommentComposerViewController {
    func setupLayout() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        accountButton.titleLabel?.numberOfLines = 2
        accountButton.titleLabel?.textAlignment = .center
        accountButton.tintColor = theme.accent
        accountButton.backgroundColor = theme.surface
        accountButton.layer.cornerRadius = 12
        accountButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        configureTextViews()
        for item in [accountButton, contextLabel, editor, statusLabel] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }
        installConstraints()
    }

    private func configureTextViews() {
        let theme = ThemeManager.shared
        contextLabel.text = target.parentAuthor.map {
            "nativeComments.replyingTo".localized(with: $0)
        }
            ?? "nativeComments.prompt".localized
        contextLabel.textColor = theme.primaryText
        contextLabel.numberOfLines = 0
        contextLabel.font = .preferredFont(forTextStyle: .headline)
        editor.font = .preferredFont(forTextStyle: .body)
        editor.backgroundColor = theme.surface
        editor.textColor = theme.primaryText
        editor.tintColor = theme.accent
        editor.layer.cornerRadius = 12
        editor.textContainerInset = UIEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        editor.accessibilityLabel = "nativeComments.prompt".localized
        editor.alwaysBounceVertical = true
        statusLabel.text = "nativeComments.publicNotice".localized
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = theme.secondaryText
    }

    private func installConstraints() {
        let safe = view.safeAreaLayoutGuide
        let bottom = statusLabel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16)
        self.bottom = bottom
        NSLayoutConstraint.activate([
            accountButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            accountButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            accountButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            accountButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            contextLabel.topAnchor.constraint(equalTo: accountButton.bottomAnchor, constant: 16),
            contextLabel.leadingAnchor.constraint(equalTo: accountButton.leadingAnchor),
            contextLabel.trailingAnchor.constraint(equalTo: accountButton.trailingAnchor),
            editor.topAnchor.constraint(equalTo: contextLabel.bottomAnchor, constant: 12),
            editor.leadingAnchor.constraint(equalTo: accountButton.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: accountButton.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),
            statusLabel.leadingAnchor.constraint(equalTo: accountButton.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: accountButton.trailingAnchor),
            bottom
        ])
    }
}
