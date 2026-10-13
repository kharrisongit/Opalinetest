import AVFoundation
import UIKit

final class AirPlayHandoffState {
    weak var pending: AVPlayerItem?
    weak var attempted: AVPlayerItem?
}

struct AirPlayHandoff {
    let player: AVPlayer
    let item: AVPlayerItem
    let source: VideoSource
    let token: CancellationToken
    let resumeAt: CMTime?
    let userPauseTime: CFTimeInterval
    let wasPlaying: Bool
}

extension WatchViewController {
    var airPlayPlayer: AVPlayer? {
        guard let player = videoPlayerView?.player,
              BackgroundPlaybackService.isAirPlayActive(player: player) else {
            return nil
        }
        return player
    }

    /// Also called before ordinary error recovery: a receiver rejecting AV1
    /// must not send us through another resolver with the same incompatible pick.
    @discardableResult
    func prepareAirPlayPlayback() -> Bool {
        guard let view = videoPlayerView, view.isAirPlayActive,
              let player = view.player, let item = player.currentItem else {
            return false
        }
        if airPlayHandoffState.pending === item {
            return true
        }
        guard !pageLoadToken.isCancelled, airPlayHandoffState.attempted !== item,
              let source = playbackFacade.activeVideoSource,
              let quality = source.airPlayQuality else {
            return false
        }
        let handoff = AirPlayHandoff(
            player: player, item: item, source: source, token: pageLoadToken,
            resumeAt: rebuildPlayhead, userPauseTime: view.multitaskPause.lastUserPause,
            wasPlaying: !view.isAtEnd && (player.rate > 0 || view.interruption.lastPlayingAt
                > view.multitaskPause.lastUserPause)
        )
        beginAirPlayHandoff(handoff, quality: quality)
        return true
    }

    private func beginAirPlayHandoff(_ handoff: AirPlayHandoff, quality: VideoQuality) {
        airPlayHandoffState.pending = handoff.item
        airPlayHandoffState.attempted = handoff.item
        AppLog.player("AirPlay: preparing \(quality.label) on \(handoff.source.name)")
        handoff.source.selectQuality(
            quality, resumeAt: handoff.resumeAt.map(CMTimeGetSeconds)
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.finishAirPlayHandoff(handoff, result: result)
            }
        }
    }

    private func finishAirPlayHandoff(
        _ handoff: AirPlayHandoff, result: Result<PreparedPlayback, Error>
    ) {
        guard airPlayHandoffState.pending === handoff.item else {
            return
        }
        airPlayHandoffState.pending = nil
        guard pageLoadToken === handoff.token, !handoff.token.isCancelled,
              videoPlayerView?.player === handoff.player,
              handoff.player.currentItem === handoff.item,
              playbackFacade.activeVideoSource === handoff.source else {
            return
        }
        switch result {
        case .success(let prepared):
            attachAirPlayPlayback(prepared, handoff: handoff)
        case .failure(let error):
            AppLog.player("AirPlay: compatible stream failed: \(error.localizedDescription)")
            if handoff.item.status == .failed {
                recoverPlayback()
            }
        }
    }

    private func attachAirPlayPlayback(_ prepared: PreparedPlayback, handoff: AirPlayHandoff) {
        let resumeAt = rebuildPlayhead ?? handoff.resumeAt
        // Keep the AVPlayer that owns the receiver connection, even if the
        // route briefly stops reporting active while the old item is rejected.
        savedPlayerForBackground = handoff.player
        attachPrepared(prepared, resumeAt: resumeAt)
        if !handoff.wasPlaying
            || (videoPlayerView?.multitaskPause.lastUserPause ?? 0) > handoff.userPauseTime {
            handoff.player.pause()
        }
        AppLog.player("AirPlay: compatible item attached to the existing player")
    }
}
