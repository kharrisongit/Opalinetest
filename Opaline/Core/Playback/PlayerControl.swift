import Foundation

// swiftlint:disable redundant_string_enum_value
enum PlayerControl: String, CaseIterable {
    case airPlay = "airPlay"
    case speed = "speed"
    case captions = "captions"
    case pictureInPicture = "pictureInPicture"
    case loop = "loop"
    case audioOnly = "audioOnly"

    static let didChange = Notification.Name("playerControlVisibilityDidChange")

    var title: String { "player.controls.\(rawValue)".localized }

    var isVisible: Bool {
        get {
            UserDefaults.standard.object(
                forKey: UserDefaultsKeys.Player.controlVisibility(rawValue)
            ) as? Bool ?? (self != .audioOnly)
        }
        nonmutating set {
            UserDefaults.standard.set(
                newValue, forKey: UserDefaultsKeys.Player.controlVisibility(rawValue)
            )
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }
}
// swiftlint:enable redundant_string_enum_value
