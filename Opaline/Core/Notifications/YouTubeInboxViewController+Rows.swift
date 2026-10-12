import SafariServices
import UIKit

extension YouTubeInboxViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let item = items[indexPath.row]
        let theme = ThemeManager.shared
        let cell = tableView.dequeueReusableCell(withIdentifier: "notification")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "notification")
        let read = item.isRead || YouTubeInboxService.shared.readIDs.contains(item.id)
        cell.textLabel?.text = item.message
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = read ? .systemFont(ofSize: 16) : .boldSystemFont(ofSize: 16)
        cell.textLabel?.textColor = theme.primaryText
        cell.detailTextLabel?.text = item.time
        cell.detailTextLabel?.textColor = theme.secondaryText
        cell.backgroundColor = theme.surface
        cell.accessoryType = .disclosureIndicator
        let selected = UIView()
        selected.backgroundColor = theme.primaryText.withAlphaComponent(0.1)
        cell.selectedBackgroundView = selected
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
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
