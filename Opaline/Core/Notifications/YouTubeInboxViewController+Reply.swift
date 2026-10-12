import UIKit

extension YouTubeInboxViewController {
    var replyRow: Int? {
        items.firstIndex { $0.id == activeReplyID }.map { $0 + 1 }
    }

    func item(at row: Int) -> YouTubeNotification? {
        if row == replyRow {
            return nil
        }
        let index = row - ((replyRow.map { row > $0 } ?? false) ? 1 : 0)
        return items.indices.contains(index) ? items[index] : nil
    }

    func openInlineReply(_ item: YouTubeNotification) {
        closeInlineReply()
        YouTubeInboxService.shared.markRead(item.id)
        activeReplyID = item.id
        let reply = NotificationReplyView(item: item)
        replyView = reply
        reply.onClose = { [weak self] in self?.closeInlineReply() }
        reply.onConnect = { [weak self] in self?.openAccount() }
        reply.onResize = { [weak self] in self?.resizeReply() }
        tableView.reloadData()
        if let row = replyRow {
            tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .middle, animated: true)
        }
        reply.load()
    }

    func closeInlineReply() {
        replyView?.cancel()
        replyView?.removeFromSuperview()
        replyView = nil
        activeReplyID = nil
        if isViewLoaded { tableView.reloadData() }
    }

    func resizeReply() {
        // Defer text-view callbacks until its current layout pass is finished.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.replyView != nil else {
                return
            }
            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
            }
        }
    }

    func replyCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = ThemeManager.shared.surface
        guard let replyView else {
            return cell
        }
        replyView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(replyView)
        NSLayoutConstraint.activate([
            replyView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            replyView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            replyView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            replyView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
        ])
        return cell
    }
}
