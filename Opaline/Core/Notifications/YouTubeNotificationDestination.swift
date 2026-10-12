import Foundation

/// Only navigation data is accepted. Returned commands never choose a request host or API path.
struct YouTubeNotificationDestination {
    let videoID: String?
    let commentID: String?
    let channelID: String?
    let url: URL?

    init(endpoint: [String: Any]) {
        let metadata = endpoint["commandMetadata"] as? [String: Any]
        let web = metadata?["webCommandMetadata"] as? [String: Any]
        let urlEndpoint = endpoint["urlEndpoint"] as? [String: Any]
        let link = Self.safeURL(web?["url"] as? String ?? urlEndpoint?["url"] as? String)
        let watch = endpoint["watchEndpoint"] as? [String: Any]
            ?? endpoint["reelWatchEndpoint"] as? [String: Any]
        let browse = endpoint["browseEndpoint"] as? [String: Any]
        videoID = watch?["videoId"] as? String ?? link.flatMap(YouTubeLinkParser.videoId)
        let query = link.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }?.queryItems
        commentID = query?.first { $0.name == "lc" }?.value
        let browseID = browse?["browseId"] as? String
        channelID = browseID?.hasPrefix("UC") == true ? browseID : nil
        url = link
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
