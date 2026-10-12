import Foundation

enum HomePreviewPolicy {
    static func allows(visible: Bool, active: Bool, mainPlayerInUse: Bool, airPlay: Bool) -> Bool {
        visible && active && !mainPlayerInUse && !airPlay
    }
}
