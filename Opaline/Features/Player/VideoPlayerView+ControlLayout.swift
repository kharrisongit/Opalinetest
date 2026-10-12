import UIKit

extension VideoPlayerView {
    func installTopControls() {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(scroll)
        topControls.spacing = 4
        topControls.alignment = .center
        topControls.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(topControls)
        let buttons: [UIView] = [
            loopButton, audioOnlyButton, speedButton,
            ccButton, pipButton, airPlayButton, settingsButton
        ]
        for button in buttons {
            topControls.addArrangedSubview(button)
            let width = button.widthAnchor.constraint(equalToConstant: 36)
            width.priority = UILayoutPriority(999)
            width.isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }
        constrainTopControls(scroll)
        airPlayButton.onOpen = { [weak self] in self?.hideWorkItem?.cancel() }
        airPlayButton.onClose = { [weak self] in self?.scheduleAutoHide() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshTopControls),
            name: PlayerControl.didChange,
            object: nil
        )
        refreshTopControls()
    }

    private func constrainTopControls(_ scroll: UIScrollView) {
        let safeArea = controlsView.safeAreaLayoutGuide
        let fit = scroll.widthAnchor.constraint(equalTo: topControls.widthAnchor)
        fit.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -28),
            scroll.leadingAnchor.constraint(
                greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 16
            ),
            scroll.heightAnchor.constraint(equalToConstant: 36),
            fit,
            topControls.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            topControls.trailingAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.trailingAnchor
            ),
            topControls.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            topControls.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            topControls.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
    }

    @objc
    func refreshTopControls() {
        airPlayButton.isHidden = !PlayerControl.airPlay.isVisible
        speedButton.isHidden = !PlayerControl.speed.isVisible
        ccButton.isHidden = !PlayerControl.captions.isVisible
        pipButton.isHidden = !PlayerControl.pictureInPicture.isVisible
        loopButton.isHidden = !PlayerControl.loop.isVisible
        audioOnlyButton.isHidden = !PlayerControl.audioOnly.isVisible || !audioOnlyAvailable
        if speedButton.isHidden { speedOverlay.isHidden = true }
    }
}
