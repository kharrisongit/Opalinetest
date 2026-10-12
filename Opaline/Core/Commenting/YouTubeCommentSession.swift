import CommonCrypto
import Foundation

struct YouTubeCommentCookie: Codable {
    let name: String
    let value: String
    let expires: Date?

    init(_ cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        expires = cookie.expiresDate
    }
}

struct YouTubeCommentSession: Codable {
    var cookies: [YouTubeCommentCookie]
    let contextData: Data
    let accountIndex: String
    let pageID: String?
    var channel: CommentAPIChannel?

    static func isYouTubeCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased()
        return [".youtube.com", "youtube.com", "www.youtube.com"].contains(domain)
            && cookie.path == "/" && cookie.isSecure
    }

    func headers(now: Date = Date()) throws -> [String: String] {
        let valid = cookies.filter { $0.expires.map { $0 > now } ?? true }
        guard let sid = valid.first(where: { $0.name == "SAPISID" }), !sid.value.isEmpty else {
            throw CommentAPIError(reason: "signedOut")
        }
        let timestamp = Int(now.timeIntervalSince1970)
        let input = Data("\(timestamp) \(sid.value) https://www.youtube.com".utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        input.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(input.count), &digest)
        }
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        var headers = [
            "Authorization": "SAPISIDHASH \(timestamp)_\(hash)",
            "Cookie": valid.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
            "Origin": "https://www.youtube.com",
            "X-Origin": "https://www.youtube.com",
            "X-Goog-AuthUser": accountIndex,
            "Content-Type": "application/json"
        ]
        if let pageID, !pageID.isEmpty {
            headers["X-Goog-PageId"] = pageID
        }
        return headers
    }

    func context() throws -> [String: Any] {
        guard var context = try JSONSerialization.jsonObject(with: contextData) as? [String: Any],
              let client = context["client"] as? [String: Any],
              ["WEB", "MWEB"].contains(client["clientName"] as? String ?? "") else {
            throw CommentAPIError(reason: "response")
        }
        if let pageID, !pageID.isEmpty {
            var user = context["user"] as? [String: Any] ?? [:]
            user["onBehalfOfUser"] = pageID
            context["user"] = user
        }
        return context
    }
}
