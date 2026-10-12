import Foundation

struct WebRangeDeliveryFactory: StreamDeliveryFactory {
    let loader: WebPlaybackLoader
    let label = "web-range"

    func canServe(_ info: DirectPlaybackInfo) -> Bool {
        info.dashVideoFormat?.hasDirectURL == true && info.dashAudioFormat?.hasDirectURL == true
    }

    func make(
        client: PlaybackClient, transport: HTTPTransport, poToken: Data?
    ) -> StreamDelivery {
        WebRangeDelivery(scriptURL: loader.scriptURL)
    }
}

/// Resolve only the selected pair; quality changes use the same player JS snapshot.
final class WebRangeDelivery: StreamDelivery {
    let label = "web-range"
    private let scriptURL: URL?

    init(scriptURL: URL?) {
        self.scriptURL = scriptURL
    }

    func prepare(
        _ request: DeliveryRequest,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        resolve(request.video) { [weak self] video in
            guard let self, let video else {
                completion(.failure(WebPlaybackError.solveFailed))
                return
            }
            resolve(request.audio) { audio in
                guard let audio else {
                    completion(.failure(WebPlaybackError.solveFailed))
                    return
                }
                self.build(request, video: video, audio: audio, completion: completion)
            }
        }
    }

    private func resolve(_ format: DashFormatInfo, completion: @escaping (URL?) -> Void) {
        guard WebPlaybackProfile.mediaURL(format.url.absoluteString) != nil else {
            completion(nil)
            return
        }
        let solveThrottle: (URL?) -> Void = { [weak self] url in
            guard let self, let url else {
                completion(nil)
                return
            }
            solveThrottleURL(url, completion: completion)
        }
        guard let signature = format.sigChallenge else {
            solveThrottle(format.url)
            return
        }
        guard let scriptURL else {
            completion(nil)
            return
        }
        HLSStreamResolver.shared.solveSig(
            unsolved: signature, jsPath: scriptURL.absoluteString
        ) { solved in
            DispatchQueue.main.async {
                solveThrottle(solved.flatMap {
                    WebStreamURL.replacing(format.sigParam ?? "signature", with: $0, in: format.url)
                })
            }
        }
    }

    private func solveThrottleURL(_ url: URL, completion: @escaping (URL?) -> Void) {
        guard let challenge = WebStreamURL.challenge(in: url) else {
            completion(url)
            return
        }
        guard let scriptURL else {
            completion(nil)
            return
        }
        HLSStreamResolver.shared.solveN(
            unsolved: challenge, jsPath: scriptURL.absoluteString
        ) { solved in
            DispatchQueue.main.async {
                completion(solved.flatMap { WebStreamURL.replacing("n", with: $0, in: url) })
            }
        }
    }

    private func build(
        _ request: DeliveryRequest,
        video: URL,
        audio: URL,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        let input = HLSPlaybackBuilder.BuildInput(
            videoURL: video,
            audioURL: audio,
            videoFormat: request.video,
            audioFormat: request.audio,
            headers: EmbeddedWebClient().streamHeaders(visitorData: nil),
            startAt: request.resumeAt,
            invalidatesVisitorOnFailure: false
        )
        HLSPlaybackBuilder.build(input: input) { result in
            guard let result else {
                completion(.failure(StreamDeliveryError.noStream))
                return
            }
            completion(.success(PreparedPlayback(
                item: result.playerItem,
                resourceLoader: result.loader,
                captions: request.info.captionTracks,
                duration: request.info.duration
            )))
        }
    }
}
