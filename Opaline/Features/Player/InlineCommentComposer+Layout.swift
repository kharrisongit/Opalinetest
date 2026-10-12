import UIKit

extension InlineCommentComposer {
    func setupLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        setupEditor()
        setupReplyRow()
        let input = UIStackView(arrangedSubviews: [editor, sendButton])
        input.axis = .horizontal
        input.alignment = .bottom
        input.spacing = 8
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        CommentControlStyle.apply(sendButton)
        accountButton.contentHorizontalAlignment = .leading
        accountButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        accountButton.titleLabel?.lineBreakMode = .byTruncatingTail
        status.font = .preferredFont(forTextStyle: .caption1)
        status.numberOfLines = 0
        for item in [replyRow, accountButton, input, status] {
            stack.addArrangedSubview(item)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        applyTheme()
    }

    private func setupEditor() {
        editor.font = .preferredFont(forTextStyle: .body)
        editor.layer.cornerRadius = 10
        editor.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        editor.accessibilityLabel = "nativeComments.placeholder".localized
        editorHeight = editor.heightAnchor.constraint(equalToConstant: 44)
        editorHeight?.isActive = true
        placeholder.text = "nativeComments.placeholder".localized
        placeholder.font = editor.font
        placeholder.isUserInteractionEnabled = false
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        editor.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: editor.topAnchor, constant: 10),
            placeholder.leadingAnchor.constraint(equalTo: editor.leadingAnchor, constant: 13)
        ])
    }

    private func setupReplyRow() {
        replyRow.axis = .horizontal
        replyRow.spacing = 8
        replyRow.isHidden = true
        replyLabel.font = .preferredFont(forTextStyle: .caption1)
        replyLabel.lineBreakMode = .byTruncatingTail
        cancelReplyButton.setTitle("common.cancel".localized, for: .normal)
        cancelReplyButton.setContentHuggingPriority(.required, for: .horizontal)
        replyRow.addArrangedSubview(replyLabel)
        replyRow.addArrangedSubview(cancelReplyButton)
    }

    func applyTheme() {
        let theme = ThemeManager.shared
        backgroundColor = theme.surface
        editor.backgroundColor = theme.background
        editor.textColor = theme.primaryText
        editor.tintColor = theme.accent
        placeholder.textColor = theme.secondaryText
        status.textColor = theme.secondaryText
        replyLabel.textColor = theme.secondaryText
        accountButton.tintColor = theme.accent
        cancelReplyButton.tintColor = theme.accent
        sendButton.backgroundColor = theme.accent
    }
}

enum CommentControlStyle {
    static func apply(_ button: UIButton) {
        button.backgroundColor = ThemeManager.shared.accent
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
    }
}
