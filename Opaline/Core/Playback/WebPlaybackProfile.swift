import Foundation

/// Experimental website profiles, deliberately separate from the proven default chain.
enum WebPlaybackProfile {
    case nativeHLS
    case embedded

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15"
    static let fallbackVersion = "2.20260708.00.00"

    var clientName: String { self == .embedded ? "WEB_EMBEDDED_PLAYER" : "WEB" }
    var headerName: String { self == .embedded ? "56" : "1" }

    /// Reject restrictions and unrelated responses before interpreting any stream URLs.
    static func streamingData(_ json: [String: Any], videoID: String) throws -> [String: Any] {
        let status = json["playabilityStatus"] as? [String: Any]
        guard status?["status"] as? String == "OK" else {
            throw WebPlaybackError.unavailable
        }
        guard (json["videoDetails"] as? [String: Any])?["videoId"] as? String == videoID,
              let data = json["streamingData"] as? [String: Any] else {
            throw WebPlaybackError.invalidResponse
        }
        guard data["licenseInfos"] == nil else {
            throw WebPlaybackError.unavailable
        }
        return data
    }

    static func mediaURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https",
              url.user == nil, url.password == nil, url.port == nil,
              let host = url.host?.lowercased(),
              host == "googlevideo.com" || host.hasSuffix(".googlevideo.com") else {
            return nil
        }
        return url
    }

    static func isHLS(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "#EXTM3U" else {
            return false
        }
        return lines.contains { $0.hasPrefix("#EXT-X-STREAM-INF:") || $0.hasPrefix("#EXTINF:") }
            && lines.contains { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    func pageURL(videoID: String) throws -> URL {
        guard videoID.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil,
              let url = URL(string: self == .embedded
                  ? "https://www.youtube.com/embed/\(videoID)"
                  : "https://www.youtube.com/watch?v=\(videoID)") else {
            throw WebPlaybackError.invalidResponse
        }
        return url
    }

    func context(config: WebPlayerConfiguration) -> [String: Any] {
        var client: [String: Any] = [
            "clientName": clientName, "clientVersion": config.version,
            "userAgent": Self.userAgent, "browserName": "Safari", "browserVersion": "15.5",
            "osName": "Macintosh", "osVersion": "10_15_7", "hl": "en", "gl": "US"
        ]
        client["visitorData"] = config.visitorData
        var context: [String: Any] = ["client": client]
        if self == .embedded {
            context["thirdParty"] = ["embedUrl": "https://github.com/kharrisongit/utube"]
        }
        return context
    }

    func body(videoID: String, config: WebPlayerConfiguration) -> [String: Any] {
        var playback: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        playback["signatureTimestamp"] = config.timestamp
        return [
            "context": context(config: config), "videoId": videoID,
            "playbackContext": ["contentPlaybackContext": playback]
        ]
    }
}

enum WebPlaybackError: LocalizedError {
    case unavailable
    case invalidResponse
    case timedOut
    case solveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "This video or session does not offer this experimental playback method."
        case .invalidResponse:
            return "The experimental playback response was incomplete."
        case .timedOut:
            return "The experimental playback method timed out."
        case .solveFailed:
            return "The web player signature could not be resolved."
        }
    }
}
