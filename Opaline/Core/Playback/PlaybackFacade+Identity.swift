import Foundation

struct ResolveAttempt {
    let videoId: String
    let apiClient: WatchService
    let cancellationToken: CancellationToken
    let parentCancellation: CancellationToken
    let startedAt: Date
    let generation: Int
}

extension PlaybackFacade {
    func retryOnFreshIdentity(
        _ result: Swift.Result<PreparedPlayback, Error>,
        attempt: ResolveAttempt
    ) -> Bool {
        guard case .failure(let error) = result,
              error as? PlaybackFailure == .botCheck,
              identityRedraws == 0,
              PlaybackRecoveryGate.shared.claim() else {
            return false
        }
        identityRedraws = 1
        resolveToken.cancel()
        activeVideoSource?.releaseResources()
        InnertubeSession.invalidateVisitorIdentity(reason: "confirmed bot check", notify: false)
        AppLog.player("bot check: cancelled old requests; one coordinated identity retry in 3s")
        context?.updateStatusLabel("player.status.botCheckRetry".localized)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, resolveGeneration == attempt.generation,
                  !attempt.parentCancellation.isCancelled else {
                      return
                  }
            start(
                videoId: attempt.videoId, apiClient: attempt.apiClient,
                cancellationToken: attempt.parentCancellation
            )
        }
        return true
    }

    func restartAfterManualReset() {
        guard let videoId = currentVideoId, let apiClient = currentApiClient,
              let cancellation = loadCancellation, !cancellation.isCancelled else {
                  return
              }
        identityRedraws = 1
        AppLog.player("manual visitor reset: restarting current video")
        start(videoId: videoId, apiClient: apiClient, cancellationToken: cancellation)
    }

    func offerVerification(cancellation: CancellationToken) {
        guard let videoId = currentVideoId, let apiClient = currentApiClient else {
            return
        }
        let expected = resolveGeneration
        context?.offerYouTubeVerification(videoId: videoId) { [weak self] in
            guard let self, !cancellation.isCancelled,
                  resolveGeneration == expected else {
                      return
                  }
            identityRedraws = 1
            AppLog.player("verification: user requested native playback retry")
            start(videoId: videoId, apiClient: apiClient, cancellationToken: cancellation)
        }
    }
}
