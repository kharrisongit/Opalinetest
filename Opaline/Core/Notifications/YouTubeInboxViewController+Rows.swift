import UIKit

extension YouTubeInboxViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: YouTubeNotificationCell.reuseID, for: indexPath
        )
        (cell as? YouTubeNotificationCell)?.configure(item) { [weak self] in
            self?.openThread(item, focusReply: true)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openThread(items[indexPath.row], focusReply: false)
    }

    private func openThread(_ item: YouTubeNotification, focusReply: Bool) {
        YouTubeInboxService.shared.markRead(item.id)
        tableView.reloadData()
        let thread = NotificationThreadController(item: item, focusReply: focusReply)
        navigationController?.pushViewController(thread, animated: true)
    }
}
