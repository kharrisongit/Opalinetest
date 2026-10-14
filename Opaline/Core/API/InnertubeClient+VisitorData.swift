import Foundation

// MARK: - Playback & Visitor Data

extension InnertubeClient {
    static func extractVisitorData(from data: Data?) -> String? {
        guard
            let data,
            let html = String(data: data, encoding: .utf8),
            let start = html.range(of: "\"VISITOR_DATA\":\""),
            let end = html[start.upperBound...].range(of: "\"")
        else {
            return nil
        }
        let value = String(html[start.upperBound..<end.lowerBound])
        AppLog.innertube("extracted visitorData: \(value.prefix(30))...")
        return value
    }

    static func logPreflightCookies() {
        guard
            let base = URL(string: AppURLs.YouTube.base),
            let cookies = HTTPCookieStorage.shared.cookies(for: base)
        else {
            return
        }
        let names = cookies.map { $0.name }.joined(separator: ", ")
        AppLog.innertube("cookies after preflight: \(names)")
    }

    static func logVisitorCookies() {
        guard
            let base = URL(string: AppURLs.YouTube.base),
            let cookies = HTTPCookieStorage.shared.cookies(for: base),
            let vis = cookies.first(where: { $0.name == "VISITOR_INFO1_LIVE" }),
            let priv = cookies.first(where: { $0.name == "VISITOR_PRIVACY_METADATA" })
        else {
            return
        }
        AppLog.innertube(
            "VISITOR_INFO1_LIVE=\(vis.value.prefix(20))..." +
            " PRIVACY_METADATA=\(priv.value.prefix(20))..."
        )
    }

    func oauthPlayback(
        videoId: String,
        playbackClient: PlaybackClient,
        poToken: String? = nil,
        cancellation: CancellationToken? = nil,
        completion: @escaping (Result<DirectPlaybackInfo, Error>) -> Void
    ) {
        OAuthClient.shared.validToken { [weak self] result in
            guard cancellation?.isCancelled != true else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let token):
                // TV refuses a /player without a signature timestamp, and it
                // must be the one belonging to the player that answers the `n`
                // — see `tvSignatureTimestamp`. Other OAuth clients keep the
                // site-wide value.
                let timestamps = SignatureTimestampService.shared
                let resolve = playbackClient.needsSignatureSolver
                    ? timestamps.tvSignatureTimestamp
                    : timestamps.fetch
                resolve { sts in
                    self?.executeDirectPlayback(
                        videoId: videoId,
                        client: playbackClient,
                        token: token,
                        poToken: poToken,
                        visitorData: nil,
                        signatureTimestamp: sts,
                        cancellationToken: cancellation,
                        completion: completion
                    )
                }
            }
        }
    }

    func anonymousPlayback(
        videoId: String,
        playbackClient: PlaybackClient,
        poToken: String? = nil,
        cancellation: CancellationToken? = nil,
        completion: @escaping (Result<DirectPlaybackInfo, Error>) -> Void
    ) {
        let requestToken = VisitorIdentityStore.shared.childToken(parent: cancellation)
        let dispatch: (String?) -> Void = { [weak self] visitorData in
            guard !requestToken.isCancelled else {
                return
            }
            self?.executeDirectPlayback(
                videoId: videoId,
                client: playbackClient,
                token: "",
                poToken: poToken,
                visitorData: visitorData,
                cancellationToken: requestToken,
                completion: completion
            )
        }
        if let cached = session.visitorData {
            AppLog.innertube("visitorData cache hit for \(videoId)")
            dispatch(cached)
            return
        }
        fetchVisitorData(
            videoId: videoId,
            cancellationToken: requestToken
        ) { visitorData in
            guard !requestToken.isCancelled else {
                return
            }
            dispatch(visitorData)
        }
    }

    func fetchVisitorData(
        videoId: String,
        cancellationToken: CancellationToken? = nil,
        completion: @escaping (String?) -> Void
    ) {
        guard let parts = visitorRequestParts(videoId: videoId) else {
            completion(nil)
            return
        }
        let request = HTTPRequest(
            method: .get, url: parts.url, headers: parts.headers,
            timeout: 12, sendsCookies: false, isPlayback: true
        )
        VisitorIdentityStore.shared.fetch(request) { value in
            guard cancellationToken?.isCancelled != true else {
                return
            }
            completion(value)
        }
    }

    func visitorRequestParts(
        videoId: String
    ) -> (url: URL, headers: [String: String])? {
        let base = "https://www.youtube.com/watch"
        let qs = "?v=\(videoId)&bpctr=9999999999&has_verified=1"
        guard let url = URL(string: base + qs) else {
            return nil
        }
        AppLog.innertube("fetching visitor data for \(videoId)...")
        // MUST stay English regardless of the content-language setting:
        // visitorData minting is BotGuard/fingerprint-adjacent, and the
        // minted token must match a stable request profile.
        let headers = [
            HTTPHeader.userAgent: UserAgent.chromeDesktopPlayback,
            HTTPHeader.accept:
                "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            HTTPHeader.acceptLanguage: "en-us,en;q=0.5",
            "Cookie": "PREF=hl=en&tz=UTC; SOCS=CAI"
        ]
        return (url, headers)
    }

}
