import Foundation

/// Read the timestamp and JS path from the same page; never mix in a TV player timestamp.
struct WebPlayerConfiguration {
    var version: String
    var visitorData: String?
    var timestamp: Int?
    var scriptURL: URL?
    var encryptedHostFlags: String?

    init(html: String, profile: WebPlaybackProfile = .nativeHLS) {
        version = Self.string("INNERTUBE_CLIENT_VERSION", in: html)
            ?? profile.version
        if profile == .legacyTV {
            version = profile.version
        }
        visitorData = Self.string("VISITOR_DATA", in: html)
        timestamp = Self.signatureTimestamp(in: html)
        let path = Self.string("PLAYER_JS_URL", in: html)
            ?? Self.string("jsUrl", in: html)
        scriptURL = Self.validScriptURL(path)
        encryptedHostFlags = Self.string("encryptedHostFlags", in: html)
    }

    static func signatureTimestamp(in text: String) -> Int? {
        guard let value = capture(
            #"(?:"STS"|"sts"|"signatureTimestamp"|signatureTimestamp|sts)\s*:\s*([0-9]+)"#,
            in: text
        ) else {
            return nil
        }
        return Int(value)
    }

    static func validScriptURL(_ path: String?) -> URL? {
        guard let path,
              let url = URL(string: path, relativeTo: URL(string: "https://www.youtube.com"))?
                  .absoluteURL,
              url.scheme == "https", url.host == "www.youtube.com", url.port == nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !url.path.components(separatedBy: "/").contains(".."),
              url.path.hasPrefix("/s/player/"), url.path.hasSuffix(".js") else {
            return nil
        }
        return url
    }

    private static func string(_ key: String, in text: String) -> String? {
        let pattern = "\"" + NSRegularExpression.escapedPattern(for: key)
            + #""\s*:\s*("(?:\\.|[^"\\])*")"#
        guard let encoded = capture(pattern, in: text), let data = encoded.data(using: .utf8) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(
            with: data, options: .fragmentsAllowed
        )) as? String
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}
