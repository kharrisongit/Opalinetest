import AVKit
import UIKit

final class AirPlayRouteButton: AVRoutePickerView, AVRoutePickerViewDelegate {
    private let videoStyle: Bool
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    init(videoStyle: Bool = false) {
        self.videoStyle = videoStyle
        super.init(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        delegate = self
        if #available(iOS 13.0, *) {
            prioritizesVideoDevices = true
        }
        accessibilityLabel = "player.controls.airPlay".localized
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func applyTheme() {
        tintColor = videoStyle || ThemeManager.shared.isDark ? .white : .darkGray
        activeTintColor = ThemeManager.shared.accent
    }

    func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        BackgroundPlaybackService.activate()
        onOpen?()
    }

    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        onClose?()
    }
}
