import Foundation

/// One attempt at playing a video: a client and a delivery.
///
/// Steps are what the user orders and switches off in settings, and what the
/// chain walks in that order. Adding a way to play is adding a step to the
/// registry — nothing else in the app learns its name.
struct PlaybackStep {
    /// Stable identifier, stored in settings. Never change a shipped one.
    let id: String
    /// What the settings screen and the stats overlay call this step.
    let title: String
    /// Steps that need an account skip themselves when there is no session,
    /// which is what keeps "are we signed in?" out of the playback code.
    let requiresSignIn: Bool
    var detail: String?
    var timeout: TimeInterval?
    var requiresWebsiteSignIn = false
    let make: (WatchService) -> VideoSource

    func isAvailable(isSignedIn: Bool, isWebsiteSignedIn: Bool) -> Bool {
        (!requiresSignIn || isSignedIn) && (!requiresWebsiteSignIn || isWebsiteSignedIn)
    }
}
