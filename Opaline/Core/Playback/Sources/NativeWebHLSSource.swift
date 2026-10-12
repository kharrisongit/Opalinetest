import AVFoundation
import Foundation

/// Direct HTTPS HLS, so AVPlayer/AirPlay can use Apple's adaptive playback without a web view.
final class NativeWebHLSSource: VideoSource {
    let name: String
    let supportsQualitySelection = false
    let availableQualities: [VideoQuality] = []
    let currentQuality: VideoQuality? = nil
    private let loader: WebPlaybackLoader

    init(name: String = "web.hls", profile: WebPlaybackProfile = .nativeHLS) {
        self.name = name
        loader = WebPlaybackLoader(profile: profile, delivery: .nativeHLS)
    }

    func loadPlayback(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        loader.load(videoID: videoId, cancellation: cancellation) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let info):
                validate(info, cancellation: cancellation, completion: completion)
            }
        }
    }

    private func validate(
        _ info: DirectPlaybackInfo,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        guard let url = info.hlsManifestURL else {
            completion(.failure(WebPlaybackError.unavailable))
            return
        }
        loader.resolveManifest(url) { [weak self] result in
            guard let self, cancellation?.isCancelled != true else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let resolved):
                fetchManifest(
                    resolved, info: info, cancellation: cancellation, completion: completion
                )
            }
        }
    }

    private func fetchManifest(
        _ url: URL,
        info: DirectPlaybackInfo,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        // Cookies and Authorization are deliberately absent from CDN requests and the item.
        loader.fetchText(url) { result in
            guard cancellation?.isCancelled != true else {
                return
            }
            completion(result.flatMap { text in
                guard WebPlaybackProfile.isHLS(text) else {
                    return .failure(WebPlaybackError.invalidResponse)
                }
                let item = AVPlayerItem(url: url)
                if let height = VideoQualityStore.maxHeight {
                    item.preferredMaximumResolution = CGSize(
                        width: CGFloat(height) * 16 / 9, height: CGFloat(height)
                    )
                }
                return .success(PreparedPlayback(
                    item: item, captions: info.captionTracks, duration: info.duration
                ))
            })
        }
    }

    func selectQuality(
        _ quality: VideoQuality,
        resumeAt: Double?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        completion(.failure(WebPlaybackError.unavailable))
    }

    func releaseResources() {
        loader.cancel()
    }
}
