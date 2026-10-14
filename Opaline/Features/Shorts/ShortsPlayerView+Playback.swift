import AVFoundation
import UIKit

// MARK: - PlaybackContext

extension ShortsPlayerView: PlaybackContext {
    func attachPrepared(_ prepared: PreparedPlayback, resumeAt: CMTime?) {
        play(entry: Entry(
            videoId: facade.currentVideoId ?? "",
            item: prepared.item,
            source: facade.activeVideoSource,
            loader: prepared.resourceLoader
        ))
    }

    func updateStatusLabel(_ text: String) {
        statusLabel.text = text
    }

    func showPlaybackError(_ message: String) {
        statusLabel.text = message
        // Nothing will draw, so stop waiting for a frame — the message lives
        // in this view and would stay invisible behind the hidden alpha.
        awaitedItem = nil
        alpha = 1
    }

    func offerYouTubeVerification(videoId: String, retry: @escaping () -> Void) {
        // A scrolling feed must not open repeated modal dialogs. The same
        // verification screen is always available in the playback settings.
        showPlaybackError("verification.shortsHelp".localized)
    }

    func startObservingPlayerItem(_ item: AVPlayerItem) {}

    func stopObservingPlayerItem(_ item: AVPlayerItem) {}

    func setCaptionTracks(_ tracks: [SubtitleTrack]) {}
}
