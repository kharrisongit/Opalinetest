import Foundation

extension InnertubeVideoSource {
    func invalidatePlaybackToken() {
        guard let binding = client.attestationBinding else {
            return
        }
        poTokenProvider.invalidateToken(identifier: binding, client: client.name)
        sabrPoToken = nil
    }

    func mintingTokenIfNeeded(_ completion: @escaping (Result<String?, Error>) -> Void) {
        guard let binding = client.attestationBinding else {
            sabrPoToken = nil
            completion(.success(nil))
            return
        }
        poTokenProvider.fetchSessionToken(
            identifier: binding, client: client.name
        ) { [weak self] result in
            self?.sabrPoToken = (try? result.get()).flatMap(SABRDelivery.decodeConfig)
            completion(result.map { Optional($0) })
        }
    }

    func loadWithTokenRecovery(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        loadOnce(videoId: videoId, cancellation: cancellation) { [weak self] result in
            guard let self, cancellation?.isCancelled != true else {
                return
            }
            guard case .failure(let error) = result,
                  let failure = error as? PlaybackFailure,
                  [.tokenRejected, .botCheck].contains(failure),
                  client.attestationBinding != nil else {
                completion(result)
                return
            }
            invalidatePlaybackToken()
            releaseDelivery()
            AppLog.player("\(name): retrying once with a fresh proof-of-origin token")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard cancellation?.isCancelled != true else {
                    return
                }
                self?.loadOnce(videoId: videoId, cancellation: cancellation, completion: completion)
            }
        }
    }

    private func loadOnce(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        fetchInfo(videoId: videoId, cancellation: cancellation) { [weak self] result in
            DispatchQueue.main.async {
                guard cancellation?.isCancelled != true else {
                    return
                }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let info):
                    self?.handleInfo(info, videoId: videoId) { prepared in
                        DispatchQueue.main.async {
                            guard cancellation?.isCancelled != true else {
                                return
                            }
                            completion(prepared)
                        }
                    }
                }
            }
        }
    }
}
