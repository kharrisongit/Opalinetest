import UIKit

extension NotificationThreadController {
    func setupViews() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        view.tintColor = theme.accent
        table.backgroundColor = theme.background
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 140
        table.keyboardDismissMode = .interactive
        table.dataSource = self
        table.delegate = self
        table.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseId)
        message.numberOfLines = 0
        message.textAlignment = .center
        message.textColor = theme.secondaryText
        message.font = .preferredFont(forTextStyle: .body)
        more.frame.size.height = 52
        more.addTarget(self, action: #selector(loadMore), for: .touchUpInside)
        more.isHidden = true
        table.tableFooterView = more
        arrangeViews()
    }

    private func arrangeViews() {
        let stack = contentStack
        stack.addArrangedSubview(table)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let bottom = stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom
        ])
        keyboardGuide = CommentKeyboardGuide(host: view, bottom: bottom)
        composer.isHidden = true
    }

    func setComposerVisible(_ visible: Bool) {
        // Detach a hidden composer so its editor height cannot fight a zero-height stack row.
        if visible {
            composer.isHidden = false
            if composer.superview == nil { contentStack.addArrangedSubview(composer) }
        } else {
            composer.removeFromSuperview()
            composer.isHidden = true
        }
    }

    func setupComposer() {
        composer.onConnect = { [weak self] in
            self?.navigationController?.pushViewController(
                CommentAccountViewController(), animated: true
            )
        }
        composer.onCancelReply = { [weak self] in
            guard let self else {
                return
            }
            self.composer.beginReply(to: self.parent, focus: false)
            self.view.endEditing(true)
        }
        composer.onPosted = { [weak self] comment, target in
            guard let self, target.parentID == self.parent?.id else {
                return
            }
            if !self.replies.contains(where: { $0.id == comment.id }) {
                self.replies.append(comment)
            }
            self.view.endEditing(true)
            self.updateRows()
            self.table.scrollToRow(
                at: IndexPath(row: self.replies.count, section: 0), at: .bottom, animated: true
            )
        }
    }
}

extension NotificationThreadController: UITableViewDataSource, UITableViewDelegate,
    UITextViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        parent == nil ? 0 : replies.count + 1
    }

    func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CommentCell.reuseId, for: indexPath
        )
        guard let parent else {
            return cell
        }
        let comment = indexPath.row == 0 ? parent : replies[indexPath.row - 1]
        let reply: (() -> Void)? = composer.isHidden ? nil : { [weak self] in
            self?.composer.beginReply(to: parent, recipient: comment)
        }
        (cell as? CommentCell)?.configure(
            comment, linkDelegate: self, isReply: indexPath.row > 0, onReply: reply
        )
        cell.contentView.backgroundColor = comment.id == item.destination.commentID
            ? ThemeManager.shared.accent.withAlphaComponent(0.06) : .clear
        return cell
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith url: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        // A link in a thread must not unexpectedly replace the playing video.
        false
    }
}
