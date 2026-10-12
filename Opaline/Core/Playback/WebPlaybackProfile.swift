import Foundation

/// Experimental website profiles, deliberately separate from the proven default chain.
enum WebPlaybackProfile: CaseIterable {
    case nativeHLS
    case embedded
    case mobile
    case legacyTV

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15"
    static let fallbackVersion = "2.20260708.00.00"

    var clientName: String {
        switch self {
        case .nativeHLS:
            return "WEB"
        case .embedded:
            return "WEB_EMBEDDED_PLAYER"
        case .mobile:
            return "MWEB"
        case .legacyTV:
            return "TVHTML5"
        }
    }

    var headerName: String {
        switch self {
        case .nativeHLS:
            return "1"
        case .embedded:
            return "56"
        case .mobile:
            return "2"
        case .legacyTV:
            return "7"
        }
    }

    var version: String {
        switch self {
        case .nativeHLS, .embedded:
            return Self.fallbackVersion
        case .mobile:
            return "2.20260708.05.00"
        case .legacyTV:
            return "5.20260707"
        }
    }

    var requestUserAgent: String {
        switch self {
        case .nativeHLS, .embedded:
            return Self.userAgent
        case .mobile:
            return "Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                + "Version/16.6 Mobile/15E148 Safari/604.1"
        case .legacyTV:
            return "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version"
        }
    }

    /// The compatibility TV profile uses the web player's paired STS/JS, as yt-dlp does.
    /// Its client version stays 5.x even if the watch page advertises WEB 2.x.
    var pageUserAgent: String { self == .legacyTV ? Self.userAgent : requestUserAgent }
    var usesWebsiteAccount: Bool { self != .embedded }
    var requiresWebsiteAccount: Bool { self == .legacyTV }

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
        guard videoID.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else {
            throw WebPlaybackError.invalidResponse
        }
        let host = self == .mobile ? "m.youtube.com" : "www.youtube.com"
        let path = self == .embedded ? "/embed/\(videoID)" : "/watch?v=\(videoID)"
        guard let url = URL(string: "https://\(host)\(path)") else {
            throw WebPlaybackError.invalidResponse
        }
        return url
    }

    func context(config: WebPlayerConfiguration) -> [String: Any] {
        var client: [String: Any] = [
            "clientName": clientName,
            "clientVersion": self == .legacyTV ? version : config.version,
            "userAgent": requestUserAgent, "hl": "en", "gl": "US"
        ]
        if self != .legacyTV {
            client["browserName"] = "Safari"
            client["browserVersion"] = self == .mobile ? "16.6" : "15.5"
            client["osName"] = self == .mobile ? "iPad" : "Macintosh"
            client["osVersion"] = self == .mobile ? "16.7.10" : "10_15_7"
        }
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
        if self == .embedded {
            playback["encryptedHostFlags"] = config.encryptedHostFlags
        }
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
    case accountRequired

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
        case .accountRequired:
            return "Connect your YouTube commenting account to try TV compatibility playback."
        }
    }
}
