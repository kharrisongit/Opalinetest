import Foundation

enum BackgroundPlaybackPolicy {
    static func shouldContinue(
        backgroundEnabled: Bool, airPlayActive: Bool, pipActive: Bool
    ) -> Bool {
        backgroundEnabled || airPlayActive || pipActive
    }

    static func shouldPauseAfterPiP(restoring: Bool, airPlayActive: Bool) -> Bool {
        !restoring && !airPlayActive
    }
}
