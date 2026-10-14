import UIKit

extension WatchViewController {
    func offerYouTubeVerification(videoId: String, retry: @escaping () -> Void) {
        guard viewIfLoaded?.window != nil, presentedViewController == nil,
              initialVideo.id == videoId else {
                  return
              }
        let alert = UIAlertController(
            title: "verification.title".localized,
            message: "verification.offer".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "common.cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(
            title: "verification.open".localized, style: .default
        ) { [weak self] _ in
            guard let self, initialVideo.id == videoId else {
                return
            }
            videoPlayerView?.player?.pause()
            let screen = YouTubeVerificationView(videoID: videoId, retry: retry)
            let navigation = UINavigationController(rootViewController: screen)
            navigation.modalPresentationStyle = .fullScreen
            present(navigation, animated: true)
        })
        present(alert, animated: true)
    }
}
