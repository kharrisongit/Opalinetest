import AVFoundation
import UIKit

extension HomeExplorerView {
    func observeChanges() {
        let center = NotificationCenter.default
        for name in [UIApplication.willResignActiveNotification, VideoRouter.playbackDidChange] {
            center.addObserver(self, selector: #selector(stopPreview), name: name, object: nil)
        }
        let changes = [
            UIApplication.didBecomeActiveNotification, AVAudioSession.routeChangeNotification
        ]
        for name in changes {
            center.addObserver(self, selector: #selector(sessionChanged), name: name, object: nil)
        }
        center.addObserver(
            self,
            selector: #selector(interruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @objc
    func stopPreview() { previewWork?.cancel(); previewWork = nil; preview.stop() }

    func schedulePreview() {
        guard mode == .carousel else {
            return
        }
        previewWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.checkPreview() }
        previewWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    @objc
    func checkPreview() {
        guard previewAllowed else {
            stopPreview()
            let key = VideoRouter.shared.currentVideo != nil
                ? "home.explorer.mainPlaying" : "home.explorer.previewPaused"
            centerCell?.previewStatus.text = key.localized
            return
        }
        guard let index = centerIndex, videos.indices.contains(index), let cell = centerCell else {
            return
        }
        if preview.videoID != videos[index].id {
            cell.previewStatus.text = "home.explorer.preview".localized
            preview.start(video: videos[index], in: cell.previewHost)
        }
    }

    @objc
    private func sessionChanged() {
        DispatchQueue.main.async { [weak self] in self?.checkPreview() }
    }

    @objc
    private func interruption(_ notification: Notification) {
        let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        DispatchQueue.main.async { [weak self] in
            self?.interrupted = type == AVAudioSession.InterruptionType.began.rawValue
            self?.checkPreview()
        }
    }
}
