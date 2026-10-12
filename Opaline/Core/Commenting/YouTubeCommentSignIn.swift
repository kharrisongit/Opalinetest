import UIKit
import WebKit

/// A visible, user-driven sign-in. No password interception, user-agent spoofing or silent login.
final class YouTubeCommentSignIn: UIViewController, WKNavigationDelegate {
    private let webView: WKWebView
    private let status = UILabel()
    private var busy = false

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 13.0, *) {
            configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "nativeComments.webSignIn".localized
        setupLayout()
        webView.navigationDelegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "nativeComments.useAccount".localized,
            style: .done,
            target: self,
            action: #selector(useAccount)
        )
        if let url = URL(string: "https://www.youtube.com/") {
            webView.load(URLRequest(url: url))
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            webView.stopLoading()
            if busy {
                YouTubeCommentClient.shared.cancelConnection()
            }
        }
    }

    private func setupLayout() {
        view.backgroundColor = ThemeManager.shared.background
        status.text = "nativeComments.webSignInHelp".localized
        status.textColor = ThemeManager.shared.primaryText
        status.font = .preferredFont(forTextStyle: .caption1)
        status.numberOfLines = 0
        for item in [status, webView] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            status.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            status.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            status.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            webView.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc
    private func useAccount() {
        guard !busy, webView.url?.scheme == "https",
              ["www.youtube.com", "m.youtube.com"].contains(webView.url?.host ?? "") else {
            status.text = "nativeComments.webSignInHelp".localized
            return
        }
        busy = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        let script = """
        (function() {
          if (!window.ytcfg || !ytcfg.get('LOGGED_IN')) return null;
          return {context: ytcfg.get('INNERTUBE_CONTEXT'),
            index: String(ytcfg.get('SESSION_INDEX') || 0),
            page: ytcfg.get('DELEGATED_SESSION_ID') || null};
        })()
        """
        webView.evaluateJavaScript(script) { [weak self] value, _ in
            guard let self else {
                return
            }
            guard let config = value as? [String: Any],
                  let context = config["context"] as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: context) else {
                self.finish(.failure(CommentAPIError(reason: "signedOut")))
                return
            }
            self.captureSession(config: config, context: data)
        }
    }

    private func captureSession(config: [String: Any], context: Data) {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        store.getAllCookies { [weak self] cookies in
            guard let self, self.view.window != nil else {
                return
            }
            let candidate = YouTubeCommentSession(
                cookies: cookies.filter(YouTubeCommentSession.isYouTubeCookie)
                    .map(YouTubeCommentCookie.init),
                contextData: context,
                accountIndex: config["index"] as? String ?? "0",
                pageID: config["page"] as? String,
                channel: nil
            )
            YouTubeCommentClient.shared.connect(candidate) { [weak self] result in
                self?.finish(result)
            }
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        busy = false
        navigationItem.rightBarButtonItem?.isEnabled = true
        switch result {
        case .success:
            navigationController?.popViewController(animated: true)
        case .failure(let error):
            status.text = error.localizedDescription
        }
    }
}
