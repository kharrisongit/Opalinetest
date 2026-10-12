import SafariServices
import UIKit

/// Posting uses YouTube's own form and browser sign-in. The TV OAuth token
/// used elsewhere in Opaline cannot authorize comment creation. Safari owns
/// this session; Opaline never reads its cookies or Google credentials.
enum YouTubeCommentsBrowser {
    static func make(
        videoId: String,
        delegate: SFSafariViewControllerDelegate
    ) -> SFSafariViewController? {
        guard !videoId.isEmpty else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "m.youtube.com"
        components.path = "/watch"
        components.queryItems = [URLQueryItem(name: "v", value: videoId)]
        components.fragment = "comments"
        guard let url = components.url else {
            return nil
        }
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let browser = SFSafariViewController(url: url, configuration: configuration)
        browser.delegate = delegate
        browser.dismissButtonStyle = .done
        browser.modalPresentationStyle = .fullScreen
        browser.preferredBarTintColor = ThemeManager.shared.surface
        browser.preferredControlTintColor = ThemeManager.shared.primaryText
        return browser
    }

    static func makeButton(target: Any, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("player.comments.writeOnYouTube".localized, for: .normal)
        button.accessibilityHint = "player.comments.writeHint".localized
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
}
