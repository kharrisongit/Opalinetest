import UIKit

/// Keeps the inline composer above a docked keyboard on iOS 12 and later.
final class CommentKeyboardGuide: NSObject {
    private weak var host: UIView?
    private let bottom: NSLayoutConstraint
    private var keyboardFrame: CGRect = .null

    init(host: UIView, bottom: NSLayoutConstraint) {
        self.host = host
        self.bottom = bottom
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(changed(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    func update() {
        guard let host, host.window != nil else {
            return
        }
        let frame = host.convert(keyboardFrame, from: nil)
        let intersection = host.bounds.intersection(frame)
        let docked = !intersection.isNull && frame.maxY >= host.bounds.maxY
            && intersection.width >= host.bounds.width * 0.8
        bottom.constant = -max(host.safeAreaInsets.bottom, docked ? intersection.height : 0)
    }

    @objc
    private func changed(_ note: Notification) {
        keyboardFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .null
        update()
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        UIView.animate(withDuration: duration ?? 0.25) { self.host?.layoutIfNeeded() }
    }
}
