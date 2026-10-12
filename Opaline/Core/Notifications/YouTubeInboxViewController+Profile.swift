import UIKit

extension YouTubeInboxViewController {
    func setupProfileHeader() {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 126))
        profileAvatar.layer.cornerRadius = 22
        profileAvatar.clipsToBounds = true
        profileName.font = .systemFont(ofSize: 19, weight: .semibold)
        profileName.numberOfLines = 1
        let identity = UIStackView(arrangedSubviews: [profileAvatar, profileName])
        identity.alignment = .center
        identity.spacing = 12
        let stack = UIStackView(arrangedSubviews: [identity, filter])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        NSLayoutConstraint.activate([
            profileAvatar.widthAnchor.constraint(equalToConstant: 44),
            profileAvatar.heightAnchor.constraint(equalToConstant: 44),
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16)
        ])
        tableView.tableHeaderView = header
        updateProfile()
    }

    func updateProfile() {
        let channel = YouTubeCommentClient.shared.channel
        profileName.text = channel?.title ?? "youtubeInbox.title".localized
        profileName.textColor = ThemeManager.shared.primaryText
        profileAvatar.setAvatar(
            url: channel?.avatarURL.flatMap(URL.init(string:)), name: channel?.title ?? ""
        )
    }
}
