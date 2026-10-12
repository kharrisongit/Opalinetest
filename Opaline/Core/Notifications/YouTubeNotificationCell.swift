import UIKit

final class YouTubeNotificationCell: UITableViewCell {
    static let reuseID = "YouTubeNotificationCell"
    private let avatar = ThumbnailImageView(frame: .zero)
    private let thumbnail = ThumbnailImageView(frame: .zero)
    private let message = UILabel()
    private let time = UILabel()
    private let replyButton = UIButton(type: .system)
    private var onReply: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ item: YouTubeNotification, onReply: @escaping () -> Void) {
        self.onReply = onReply
        let read = item.isRead || YouTubeInboxService.shared.readIDs.contains(item.id)
        let theme = ThemeManager.shared
        avatar.setAvatar(url: item.avatarURL.flatMap(URL.init(string:)), name: item.message)
        thumbnail.cancel()
        thumbnail.image = nil
        if let url = item.videoThumbnailURL.flatMap(URL.init(string:)) {
            thumbnail.setImage(url: url)
        }
        thumbnail.isHidden = item.videoThumbnailURL == nil
        message.text = item.message
        message.font = .systemFont(ofSize: 15, weight: read ? .regular : .semibold)
        message.textColor = theme.primaryText
        time.text = [read ? nil : "youtubeInbox.unread".localized, item.time]
            .compactMap { $0 }.joined(separator: " · ")
        time.textColor = read ? theme.secondaryText : .systemBlue
        replyButton.isHidden = item.destination.videoID == nil || item.destination.commentID == nil
        backgroundColor = read ? theme.background : UIColor.systemBlue.withAlphaComponent(0.06)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.cancel()
        thumbnail.cancel()
        onReply = nil
    }

    private func setup() {
        selectionStyle = .none
        message.numberOfLines = 0
        time.font = .systemFont(ofSize: 12)
        avatar.layer.cornerRadius = 22
        avatar.clipsToBounds = true
        thumbnail.layer.cornerRadius = 8
        thumbnail.clipsToBounds = true
        thumbnail.contentMode = .scaleAspectFill
        replyButton.setTitle("nativeComments.reply".localized, for: .normal)
        replyButton.contentHorizontalAlignment = .leading
        replyButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        replyButton.tintColor = .systemBlue
        replyButton.addTarget(self, action: #selector(reply), for: .touchUpInside)
        let text = UIStackView(arrangedSubviews: [message, time, replyButton])
        text.axis = .vertical
        text.spacing = 8
        let row = UIStackView(arrangedSubviews: [avatar, text, thumbnail])
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        constrain(row)
    }

    private func constrain(_ row: UIView) {
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),
            thumbnail.widthAnchor.constraint(equalToConstant: 80),
            thumbnail.heightAnchor.constraint(equalToConstant: 45),
            replyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    @objc
    private func reply() { onReply?() }
}
