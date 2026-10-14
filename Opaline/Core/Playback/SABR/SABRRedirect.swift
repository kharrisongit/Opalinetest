import Foundation

/// SABR redirects are protobuf control parts inside a 200 response, not HTTP
/// redirects. Only send the session's attestation to a Google video endpoint.
enum SABRRedirect {
    static let maximumHops = 3

    static func url(from payload: Data) -> URL? {
        guard let value = Protobuf.parse(payload).string(1),
              let parts = URLComponents(string: value),
              parts.scheme?.lowercased() == "https",
              let host = parts.host?.lowercased(),
              host == "googlevideo.com" || host.hasSuffix(".googlevideo.com"),
              parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443,
              parts.fragment == nil else {
            return nil
        }
        return parts.url
    }

    /// Preserve the signed query verbatim, replacing only the request number.
    static func numberedURL(_ url: URL, number: Int) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var query = (parts.percentEncodedQuery ?? "")
            .split(separator: "&")
            .map(String.init)
            .filter { !$0.hasPrefix("rn=") }
        query.append("rn=\(number)")
        parts.percentEncodedQuery = query.joined(separator: "&")
        return parts.url ?? url
    }
}
