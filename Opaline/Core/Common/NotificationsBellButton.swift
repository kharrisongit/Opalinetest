import UIKit

/// Bell bar button showing the unread-notifications inbox, with a small
/// unread dot at its top-right corner. Theming matches `ProfileAvatarButton`;
/// the dot is a plain `UIView` (not `NewContentDotView` — that type lives in
/// `Features/Subscriptions` and Core must not import Features).
final class NotificationsBellButton: UIButton {
    private static let dotSize: CGFloat = 7

    private let dotView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = NotificationsBellButton.dotSize / 2
        view.isHidden = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        setImage(resizedNavBarIcon("icon_bell", size: 22), for: .normal)
        tintColor = ThemeManager.shared.isDark ? .white : .darkGray
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: 30),
            dotView.widthAnchor.constraint(equalToConstant: NotificationsBellButton.dotSize),
            dotView.heightAnchor.constraint(equalToConstant: NotificationsBellButton.dotSize),
            dotView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            dotView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)
        ])
        for name in [
            YouTubeInboxService.didChange,
            ThemeManager.didChangeNotification
        ] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(refresh), name: name, object: nil
            )
        }
        refresh()
        YouTubeInboxService.shared.refreshCount()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func refresh() {
        tintColor = ThemeManager.shared.isDark ? .white : .darkGray
        dotView.backgroundColor = ThemeManager.shared.newContentDot
        let count = YouTubeInboxService.shared.unseenCount
        dotView.isHidden = count == 0
        accessibilityLabel = "youtubeInbox.title".localized
        accessibilityValue = count > 0 ? "youtubeInbox.unseen".localized(with: count) : nil
    }
}
