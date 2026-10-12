import AVFoundation
import UIKit

/// An isolated, silent player. It never owns the audio session, Now Playing, or watch history.
final class HomeCarouselPreview: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private let player = AVPlayer()
    private var source: VideoSource?
    private var loader: AVAssetResourceLoaderDelegate?
    private var cancellation = CancellationToken()
    private var generation = 0
    private var readiness: NSKeyValueObservation?
    private var status: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    var stillAllowed: (() -> Bool)?
    var onStatus: ((String) -> Void)?
    private(set) var videoID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.usesExternalPlaybackWhileExternalScreenIsActive = false
        if #available(iOS 15.0, *) { player.audiovisualBackgroundPlaybackPolicy = .pauses }
        (layer as? AVPlayerLayer)?.player = player
        (layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func start(video: Video, in host: UIView) {
        guard stillAllowed?() == true else {
            stop()
            return
        }
        if videoID == video.id {
            return
        }
        stop()
        videoID = video.id
        alpha = 0
        frame = host.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(self)
        let source = FallbackChainSource(
            steps: PlaybackChainSettings.activeSteps(), apiClient: ServiceContainer.watch
        )
        self.source = source
        let expected = generation
        source.loadPlayback(videoId: video.id, cancellation: cancellation) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.generation == expected, self.stillAllowed?() == true else {
                    return
                }
                self.prepared(result)
            }
        }
    }

    func stop() {
        generation += 1
        cancellation.cancel()
        cancellation = CancellationToken()
        readiness = nil
        status = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        source?.releaseResources()
        source = nil
        loader = nil
        videoID = nil
        removeFromSuperview()
    }

    private func prepared(_ result: Result<PreparedPlayback, Error>) {
        guard let prepared = try? result.get() else {
            onStatus?("home.explorer.previewUnavailable".localized)
            return
        }
        loader = prepared.resourceLoader
        prepared.item.preferredForwardBufferDuration = 3
        player.replaceCurrentItem(with: prepared.item)
        observePlayback(prepared.item)
        if stillAllowed?() == true { player.play() }
    }

    private func observePlayback(_ item: AVPlayerItem) {
        readiness = (layer as? AVPlayerLayer)?.observe(
            \.isReadyForDisplay, options: [.new]
        ) { [weak self] layer, _ in
            DispatchQueue.main.async {
                guard let self, self.stillAllowed?() == true else {
                    return
                }
                self.alpha = layer.isReadyForDisplay ? 1 : 0
            }
        }
        status = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                DispatchQueue.main.async {
                    guard let self, self.player.currentItem === item else {
                        return
                    }
                    self.alpha = 0
                    self.onStatus?("home.explorer.previewUnavailable".localized)
                }
            }
        }
        observeEnd(item)
    }

    private func observeEnd(_ item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self, self.player.currentItem === item,
                  self.stillAllowed?() == true else { return }
            self.player.seek(to: .zero) { [weak self] _ in
                if self?.player.currentItem === item, self?.stillAllowed?() == true {
                    self?.player.play()
                }
            }
        }
    }

    deinit {
        cancellation.cancel()
        source?.releaseResources()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
