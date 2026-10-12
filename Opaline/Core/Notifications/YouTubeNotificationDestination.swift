import Foundation

/// Read navigation data only. Returned commands never choose a request host or API path.
struct YouTubeNotificationDestination {
    let videoID: String?
    let commentID: String?
    let channelID: String?
    let url: URL?

    init(endpoint: [String: Any]) {
        let commands = Self.navigationCommands(endpoint)
        let links = commands.compactMap(Self.link)
        let watches = commands.compactMap {
            $0["watchEndpoint"] as? [String: Any] ?? $0["reelWatchEndpoint"] as? [String: Any]
        }
        let linked = links.first { Self.commentID(in: $0) != nil }
        url = linked ?? links.first
        videoID = linked.flatMap(YouTubeLinkParser.videoId)
            ?? watches.compactMap { $0["videoId"] as? String }.first
            ?? links.compactMap(YouTubeLinkParser.videoId).first
        commentID = linked.flatMap(Self.commentID)
            ?? watches.compactMap { $0["commentId"] as? String }.first
        channelID = commands.compactMap { $0["browseEndpoint"] as? [String: Any] }
            .compactMap { $0["browseId"] as? String }
            .first { $0.hasPrefix("UC") }
    }

    private static func commentID(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "lc" && $0.value?.isEmpty == false }?.value
    }

    private static func link(_ endpoint: [String: Any]) -> URL? {
        let metadata = endpoint["commandMetadata"] as? [String: Any]
        let web = metadata?["webCommandMetadata"] as? [String: Any]
        let urlEndpoint = endpoint["urlEndpoint"] as? [String: Any]
        return safeURL(web?["url"] as? String ?? urlEndpoint?["url"] as? String)
    }

    private static func navigationCommands(
        _ endpoint: [String: Any], depth: Int = 0
    ) -> [[String: Any]] {
        guard depth < 12 else {
            return []
        }
        let wrappers = [
            "innertubeCommand", "command", "performOnceCommand", "serviceEndpoint",
            "navigationEndpoint", "navigateAction", "endpoint"
        ]
        let nested = wrappers.compactMap { endpoint[$0] as? [String: Any] }
        let groups = ["commandExecutorCommand", "serialCommand", "parallelCommand"]
            .compactMap { endpoint[$0] as? [String: Any] }
            .flatMap { $0["commands"] as? [[String: Any]] ?? [] }
        return [endpoint] + (nested + groups).flatMap {
            navigationCommands($0, depth: depth + 1)
        }
    }

    static func safeURL(_ raw: String?) -> URL? {
        guard let raw, let base = URL(string: "https://www.youtube.com"),
              let url = URL(string: raw, relativeTo: base)?.absoluteURL,
              url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"].contains(host)
        else {
            return nil
        }
        return url
    }
}
