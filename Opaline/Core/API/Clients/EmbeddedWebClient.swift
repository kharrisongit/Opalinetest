import Foundation

/// Media-only profile. The request loader reads the matching website configuration.
/// SABR is deliberately unsupported; only explicit clear adaptive URLs are accepted.
struct EmbeddedWebClient: PlaybackClient {
    let name = "WEB_EMBEDDED_PLAYER"
    let version = WebPlaybackProfile.fallbackVersion
    let headerName = "56"
    let userAgent = WebPlaybackProfile.userAgent
    let playerURL = "player"
    let authorization = PlaybackAuthorization.anonymous
    let sendsCookies = false
    var innertubeContext: [String: Any] { [:] }

    func sabrClientInfo() -> Data { Data() }
    func sabrAbrState(_ state: SABRPlayerState) -> Data { Data() }

    func streamHeaders(visitorData: String?) -> [String: String] {
        // No account headers and no hardcoded cver added to signed media URLs.
        ["User-Agent": userAgent, "Accept": "*/*"]
    }
}
