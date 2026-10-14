import Foundation

/// Website reads only. No player window, playback side effects, identity rotation or retries.
final class WebPlaybackLoader {
    let profile: WebPlaybackProfile
    private let delivery: WebPlaybackDelivery
    private(set) var scriptURL: URL?
    private let transport: HTTPTransport
    private var token = CancellationToken()
    private var generation = 0

    init(
        profile: WebPlaybackProfile,
        delivery: WebPlaybackDelivery,
        transport: HTTPTransport = ServiceContainer.mediaTransport
    ) {
        self.profile = profile
        self.delivery = delivery
        self.transport = transport
    }

    func cancel() {
        generation += 1
        token.cancel()
        token = CancellationToken()
        scriptURL = nil
    }

    func resolveManifest(
        _ url: URL, completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let challenge = WebStreamURL.manifestChallenge(in: url) else {
            completion(.success(url))
            return
        }
        guard let scriptURL else {
            completion(.failure(WebPlaybackError.solveFailed))
            return
        }
        let expected = generation
        HLSStreamResolver.shared.solveN(
            unsolved: challenge, jsPath: scriptURL.absoluteString
        ) { [weak self] solved in
            DispatchQueue.main.async {
                guard self?.generation == expected else {
                    return
                }
                guard let solved, let resolved = WebStreamURL.replacingManifestN(
                    with: solved, in: url
                ) else {
                    completion(.failure(WebPlaybackError.solveFailed))
                    return
                }
                completion(.success(resolved))
            }
        }
    }

    func load(
        videoID: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<DirectPlaybackInfo, Error>) -> Void
    ) {
        cancel()
        guard !profile.requiresWebsiteAccount || YouTubeCommentClient.shared.channel != nil else {
            completion(.failure(WebPlaybackError.accountRequired))
            return
        }
        let expected = generation
        let finish: (Result<DirectPlaybackInfo, Error>) -> Void = { [weak self] result in
            guard self?.generation == expected, cancellation?.isCancelled != true else {
                return
            }
            completion(result)
        }
        do {
            let url = try profile.pageURL(videoID: videoID)
            fetchText(url) { [weak self] result in
                guard let self, self.generation == expected,
                      cancellation?.isCancelled != true else {
                          return
                      }
                switch result {
                case .failure(let error):
                    finish(.failure(error))
                case .success(let html):
                    configure(html: html, videoID: videoID, completion: finish)
                }
            }
        } catch {
            finish(.failure(error))
        }
    }

    private func configure(
        html: String,
        videoID: String,
        completion: @escaping (Result<DirectPlaybackInfo, Error>) -> Void
    ) {
        var config = WebPlayerConfiguration(html: html, profile: profile)
        scriptURL = config.scriptURL
        // The embed page sometimes puts STS only in its referenced player script.
        if config.timestamp == nil, let url = config.scriptURL {
            fetchText(url) { [weak self] result in
                if case .success(let script) = result {
                    config.timestamp = WebPlayerConfiguration.signatureTimestamp(in: script)
                }
                self?.readPlayer(videoID: videoID, config: config, completion: completion)
            }
        } else {
            readPlayer(videoID: videoID, config: config, completion: completion)
        }
    }

    private func readPlayer(
        videoID: String,
        config: WebPlayerConfiguration,
        completion: @escaping (Result<DirectPlaybackInfo, Error>) -> Void
    ) {
        let body = profile.body(videoID: videoID, config: config)
        let parse: (Result<[String: Any], Error>) -> Void = { [weak self] result in
            guard let self else {
                return
            }
            completion(result.flatMap { json in Result { try self.parse(json, videoID: videoID) } })
        }
        if profile.usesWebsiteAccount, YouTubeCommentClient.shared.channel != nil {
            YouTubeCommentClient.shared.readWebPlayback(
                body: body, cancellation: token, completion: parse
            )
        } else if profile.requiresWebsiteAccount {
            completion(.failure(WebPlaybackError.accountRequired))
        } else {
            readAnonymous(body: body, completion: parse)
        }
    }

    private func readAnonymous(
        body: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        do {
            let request = try WebPlaybackRequest.make(body)
            guard let url = request.url else { throw WebPlaybackError.invalidResponse }
            send(HTTPRequest(
                method: .post,
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: request.httpBody,
                timeout: 15,
                sendsCookies: false,
                isPlayback: true
            )) { result in
                completion(result.flatMap { response in
                    Result {
                        guard let json = try JSONSerialization.jsonObject(with: response.data)
                            as? [String: Any] else { throw WebPlaybackError.invalidResponse }
                        return json
                    }
                })
            }
        } catch {
            completion(.failure(error))
        }
    }

    func fetchText(_ url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        send(HTTPRequest(
            method: .get,
            url: url,
            headers: ["User-Agent": profile.pageUserAgent],
            timeout: 15,
            sendsCookies: false,
            isPlayback: true
        )) { result in
            completion(result.flatMap { response in
                guard let text = String(data: response.data, encoding: .utf8) else {
                    return .failure(WebPlaybackError.invalidResponse)
                }
                return .success(text)
            })
        }
    }

    private func send(
        _ request: HTTPRequest, completion: @escaping (Result<HTTPResponse, Error>) -> Void
    ) {
        let expected = generation
        transport.send(request, cancellationToken: token) { [weak self] result in
            DispatchQueue.main.async {
                guard self?.generation == expected else {
                    return
                }
                completion(result.flatMap { response in
                    if response.status == 429 {
                        return .failure(PlaybackFailure.rateLimited)
                    }
                    guard response.status == 200, response.data.count <= 12_000_000 else {
                        return .failure(WebPlaybackError.unavailable)
                    }
                    return .success(response)
                })
            }
        }
    }
}

extension WebPlaybackLoader {
    private func parse(_ json: [String: Any], videoID: String) throws -> DirectPlaybackInfo {
        if PlaybackFailure.isBotCheck(json) { throw PlaybackFailure.botCheck }
        _ = try WebPlaybackProfile.streamingData(json, videoID: videoID)
        var clean = InnertubeClient.unwrappingSignatureCiphers(json)
        clean["streamingData"] = try delivery.streamingData(
            from: clean["streamingData"] as? [String: Any] ?? [:]
        )
        guard let info = InnertubeClient.parseDirectPlaybackInfo(clean) else {
            throw WebPlaybackError.invalidResponse
        }
        return info
    }
}
