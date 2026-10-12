import Foundation

/// Fixed endpoint and cookieless baseline; only the account client adds session headers.
enum WebPlaybackRequest {
    static func make(_ body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false"),
              let context = body["context"] as? [String: Any],
              let client = context["client"] as? [String: Any],
              let version = client["clientVersion"] as? String,
              let profile = WebPlaybackProfile.allCases.first(where: {
                  $0.clientName == (client["clientName"] as? String)
              }) else {
            throw WebPlaybackError.invalidResponse
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json", "User-Agent": profile.requestUserAgent,
            "X-Youtube-Client-Name": profile.headerName,
            "X-Youtube-Client-Version": version, "Origin": "https://www.youtube.com"
        ]
        if let visitor = client["visitorData"] as? String {
            request.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}
