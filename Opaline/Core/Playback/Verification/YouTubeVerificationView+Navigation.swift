import WebKit

extension YouTubeVerificationView: WKNavigationDelegate, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame?.isMainFrame != false else {
            decisionHandler(.allow)
            return
        }
        let allowed = VerificationURLPolicy.allowsNavigation(navigationAction.request.url)
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationGeneration += 1
        busy = false
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationItem.rightBarButtonItem?.isEnabled = VerificationURLPolicy.isYouTube(webView.url)
        status.text = "verification.help".localized
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        status.text = "verification.loadFailed".localized
        navigationItem.rightBarButtonItem?.isEnabled = VerificationURLPolicy.isYouTube(webView.url)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil,
           VerificationURLPolicy.allowsNavigation(navigationAction.request.url) {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
