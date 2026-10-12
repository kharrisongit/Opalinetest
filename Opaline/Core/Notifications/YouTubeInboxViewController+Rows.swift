import SafariServices
import UIKit

extension YouTubeInboxViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count + (replyView == nil ? 0 : 1)
    }

    override func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let item = item(at: indexPath.row) else {
            return replyCell()
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: YouTubeNotificationCell.reuseID, for: indexPath
        )
        (cell as? YouTubeNotificationCell)?.configure(item) { [weak self] in
            self?.openInlineReply(item)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = item(at: indexPath.row) else {
            return
        }
        YouTubeInboxService.shared.markRead(item.id)
        tableView.reloadRows(at: [indexPath], with: .none)
        let destination = item.destination
        if let videoID = destination.videoID, !videoID.isEmpty {
            dismiss(animated: true) {
                VideoRouter.shared.openNotificationVideo(videoID, commentID: destination.commentID)
            }
        } else if let channelID = destination.channelID {
            let presenter = presentingViewController
            dismiss(animated: true) {
                VideoRouter.shared.openChannel(id: channelID, name: "", from: presenter)
            }
        } else {
            showDetails(item)
        }
    }

    private func showDetails(_ item: YouTubeNotification) {
        let alert = UIAlertController(
            title: item.time, message: item.message, preferredStyle: .alert
        )
        if let url = item.destination.url {
            let open = UIAlertAction(
                title: "youtubeInbox.openYouTube".localized, style: .default
            ) { [weak self] _ in
                self?.present(SFSafariViewController(url: url), animated: true)
            }
            alert.addAction(open)
        }
        alert.addAction(UIAlertAction(title: "common.close".localized, style: .cancel))
        present(alert, animated: true)
    }
}
