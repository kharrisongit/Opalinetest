import UIKit

final class HomeExplorerCell: UICollectionViewCell {
    static let reuseID = "HomeExplorerCell"
    let previewHost = UIView()
    let previewStatus = UILabel()
    private let thumbnail = ThumbnailImageView(frame: .zero)
    private let titleLabel = UILabel()
    private let channelLabel = UILabel()
    private let durationLabel = UILabel()
    private let avatar = ThumbnailImageView(frame: .zero)
    private let playButton = UIButton(type: .system)
    private var carousel = false
    private var onPlay: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 18
        contentView.clipsToBounds = true
        previewHost.clipsToBounds = true
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        previewHost.addSubview(thumbnail)
        titleLabel.numberOfLines = 2
        channelLabel.numberOfLines = 1
        durationLabel.textAlignment = .center
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        durationLabel.textColor = .white
        durationLabel.layer.cornerRadius = 5
        durationLabel.clipsToBounds = true
        durationLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        avatar.clipsToBounds = true
        previewStatus.font = .systemFont(ofSize: 12)
        playButton.setTitle("home.explorer.play".localized, for: .normal)
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        CommentControlStyle.apply(playButton)
        let views = [
            previewHost, titleLabel, channelLabel, avatar,
            previewStatus, playButton, durationLabel
        ]
        for view in views {
            contentView.addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ video: Video, carousel: Bool, onPlay: @escaping () -> Void) {
        self.carousel = carousel
        self.onPlay = onPlay
        if let url = URL(string: video.thumbnailURL) { thumbnail.setImage(url: url) }
        avatar.setAvatar(
            url: video.channelAvatarURL.flatMap(URL.init(string:)), name: video.channelName
        )
        titleLabel.text = video.title
        channelLabel.text = [video.channelName, video.viewCount]
            .compactMap { $0 }.joined(separator: " · ")
        durationLabel.text = video.isLive ? "LIVE" : video.duration
        durationLabel.isHidden = durationLabel.text?.isEmpty != false
        titleLabel.font = .systemFont(ofSize: carousel ? 18 : 11, weight: .semibold)
        channelLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = carousel ? ThemeManager.shared.primaryText : .white
        titleLabel.backgroundColor = carousel ? .clear : UIColor.black.withAlphaComponent(0.68)
        channelLabel.textColor = ThemeManager.shared.secondaryText
        previewStatus.textColor = ThemeManager.shared.secondaryText
        contentView.backgroundColor = ThemeManager.shared.surface
        contentView.layer.cornerRadius = carousel ? 22 : 12
        previewStatus.text = "home.explorer.preview".localized
        accessibilityLabel = "\(video.title), \(video.channelName)"
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = contentView.bounds.width
        let height = contentView.bounds.height
        let compact = height < 260
        let imageHeight = carousel && !compact ? min(width * 9 / 16, height - 160) : height
        previewHost.frame = CGRect(x: 0, y: 0, width: width, height: imageHeight)
        thumbnail.frame = previewHost.bounds
        durationLabel.frame = CGRect(x: width - 58, y: 8, width: 50, height: 18)
        avatar.isHidden = !carousel || compact
        channelLabel.isHidden = !carousel || compact
        previewStatus.isHidden = !carousel || compact
        playButton.isHidden = !carousel
        titleLabel.backgroundColor = !carousel || compact
            ? UIColor.black.withAlphaComponent(0.68) : .clear
        titleLabel.textColor = !carousel || compact ? .white : ThemeManager.shared.primaryText
        layoutText(imageHeight: imageHeight, compact: compact)
    }

    private func layoutText(imageHeight: CGFloat, compact: Bool) {
        let width = contentView.bounds.width
        let height = contentView.bounds.height
        if !carousel {
            titleLabel.frame = CGRect(x: 0, y: height - 32, width: width, height: 32)
            return
        }
        if compact {
            titleLabel.frame = CGRect(x: 10, y: max(0, height - 100), width: width - 20, height: 44)
            playButton.frame = CGRect(x: 14, y: max(0, height - 50), width: width - 28, height: 40)
            return
        }
        avatar.frame = CGRect(x: 14, y: imageHeight + 14, width: 30, height: 30)
        avatar.layer.cornerRadius = 15
        let start: CGFloat = compact ? 14 : 54
        titleLabel.frame = CGRect(
            x: start,
            y: imageHeight + 10,
            width: width - start - 14,
            height: 44
        )
        channelLabel.frame = CGRect(
            x: start,
            y: imageHeight + 56,
            width: width - start - 14,
            height: 18
        )
        previewStatus.frame = CGRect(x: 14, y: height - 76, width: width - 28, height: 18)
        playButton.frame = CGRect(x: 14, y: height - 54, width: width - 28, height: 42)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnail.cancel()
        avatar.cancel()
        onPlay = nil
    }

    @objc
    private func play() { onPlay?() }
}
