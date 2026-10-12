import Foundation

// Standalone macOS checks compile the same pure models the iOS app uses.
extension String { var localized: String { self } }

enum CheckFailure: Error { case failed(String) }

@main
enum NativeCommentsChecks {
    static var checks = 0

    static func expect(_ value: Bool, _ message: String) throws {
        guard value else { throw CheckFailure.failed(message) }
        checks += 1
    }

    static func rejects(_ reason: String, _ block: () throws -> Void) throws {
        do {
            try block()
            throw CheckFailure.failed("Expected rejection: \(reason)")
        } catch let error as CommentAPIError {
            try expect(error.reason == reason, "Expected \(reason), got \(error.reason)")
        }
    }

    static func main() throws {
        try oauth()
        try comments()
        try tokens()
        try playback()
        print("Passed \(checks) native commenting and AirPlay checks")
    }

    static func oauth() throws {
        let request = try CommentOAuthRequest(clientID: "123-test.apps.googleusercontent.com")
        try expect(request.verifier.count == 43 && request.state.count == 43, "Random entropy length")
        let other = try CommentOAuthRequest(clientID: request.clientID)
        try expect(request.verifier != other.verifier && request.state != other.state, "Fresh entropy")
        try expect(request.redirect == "com.googleusercontent.apps.123-test:/oauth2redirect", "Redirect")
        try expect(
            CommentOAuthRequest.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
                == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            "RFC 7636 S256 vector"
        )
        let url = try request.authorizationURL()
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        try expect(query.first { $0.name == "scope" }?.value == CommentOAuthRequest.scope, "Write scope")
        try expect(query.first { $0.name == "code_challenge_method" }?.value == "S256", "PKCE required")
        let valid = "\(request.redirect)?state=\(request.state)&code=a%2Bb%26c"
        let fields = try request.exchangeFields(callback: URL(string: valid)!)
        try expect(fields["code"] == "a+b&c" && fields["code_verifier"] == request.verifier, "Code exchange")
        let bad = [
            valid.replacingOccurrences(of: request.state, with: "wrong"),
            valid.replacingOccurrences(of: request.scheme, with: "wrong"),
            valid.replacingOccurrences(of: "/oauth2redirect", with: "/wrong"),
            valid + "&state=\(request.state)", valid + "&code=duplicate", valid + "#fragment",
            "\(request.scheme)://attacker/oauth2redirect?state=\(request.state)&code=one"
        ]
        for value in bad {
            try rejects("callback") { _ = try request.exchangeFields(callback: URL(string: value)!) }
        }
        try rejects("cancelled") {
            _ = try request.exchangeFields(callback: URL(string: "\(request.redirect)?state=\(request.state)&error=access_denied")!)
        }
        try rejects("setup") { _ = try CommentOAuthRequest(clientID: "https://attacker.invalid") }
        let encoded = String(data: CommentOAuthRequest.formBody(["code": "a+b&c= ü"]), encoding: .utf8)
        try expect(encoded == "code=a%2Bb%26c%3D%20%C3%BC", "Form encoding must preserve code bytes")
    }

    static func comments() throws {
        let top = CommentPostTarget(videoID: "video")
        let body = try top.body(text: "Native comment", channelID: "video-owner")
        let snippet = body["snippet"] as! [String: Any]
        try expect(top.endpoint == "commentThreads", "Top-level endpoint")
        try expect(snippet["channelId"] as? String == "video-owner", "Use video's channel, not author")
        try expect(snippet["videoId"] as? String == "video", "Bind post to selected video")
        let resource = snippet["topLevelComment"] as! [String: Any]
        try expect((resource["snippet"] as! [String: String])["textOriginal"] == "Native comment", "Text body")
        let reply = CommentPostTarget(videoID: "video", parentID: "parent-comment")
        let replyBody = try reply.body(text: "Reply", channelID: nil)["snippet"] as! [String: String]
        try expect(reply.endpoint == "comments" && replyBody["parentId"] == "parent-comment", "Reply parent")
        try expect(replyBody["videoId"] == nil && replyBody["textOriginal"] == "Reply", "Reply shape")
        try rejects("commentTextRequired") { _ = try top.body(text: " \n ", channelID: "owner") }
        try rejects("videoNotFound") { _ = try top.body(text: "text", channelID: nil) }
        let returned: [String: Any] = ["id": "confirmed", "snippet": ["textOriginal": "Hello", "authorDisplayName": "Channel"]]
        let created = try CommentAPIModel.createdComment(["snippet": ["topLevelComment": returned]], isReply: false)
        try expect(created.id == "confirmed" && created.content == "Hello", "Server-confirmed top-level comment")
        try expect(try CommentAPIModel.createdComment(returned, isReply: true).id == "confirmed", "Reply response")
        try rejects("uncertain") { _ = try CommentAPIModel.createdComment(["id": "missing-text"], isReply: true) }
        try rejects("response") { _ = try CommentAPIModel.json(data: Data("not JSON".utf8), status: 200) }
        try rejects("signedOut") { _ = try CommentAPIModel.json(data: Data(), status: 401) }
        let failure = Data(#"{"error":{"errors":[{"reason":"commentsDisabled"}]}}"#.utf8)
        try rejects("commentsDisabled") { _ = try CommentAPIModel.json(data: failure, status: 403) }
    }

    static func tokens() throws {
        let valid: [String: Any] = ["scope": CommentOAuthRequest.scope, "access_token": "access", "refresh_token": "refresh", "expires_in": 3600.0]
        let token = try CommentAPIModel.tokens(valid, clientID: "client")
        try expect(token.refreshToken == "refresh" && token.expires > Date(), "Initial credentials")
        var denied = valid
        denied["scope"] = "https://www.googleapis.com/auth/youtube.readonly"
        try rejects("scope") { _ = try CommentAPIModel.tokens(denied, clientID: "client") }
        var missing = valid
        missing.removeValue(forKey: "refresh_token")
        try rejects("response") { _ = try CommentAPIModel.tokens(missing, clientID: "client") }
        let renewed = try CommentAPIModel.tokens(["access_token": "new", "expires_in": 3600.0], clientID: "client", previous: token)
        try expect(renewed.accessToken == "new" && renewed.refreshToken == "refresh", "Refresh retains credential")
        try rejects("scope") { _ = try CommentAPIModel.tokens(denied, clientID: "client", previous: token) }
    }

    static func playback() throws {
        for background in [false, true] {
            for airPlay in [false, true] {
                for pip in [false, true] {
                    let result = BackgroundPlaybackPolicy.shouldContinue(backgroundEnabled: background, airPlayActive: airPlay, pipActive: pip)
                    try expect(result == (background || airPlay || pip), "Background playback policy")
                }
            }
        }
        try expect(!BackgroundPlaybackPolicy.shouldPauseAfterPiP(restoring: false, airPlayActive: true), "Closing PiP must not pause AirPlay")
        try expect(!BackgroundPlaybackPolicy.shouldPauseAfterPiP(restoring: true, airPlayActive: false), "Restoring PiP must not pause")
        try expect(BackgroundPlaybackPolicy.shouldPauseAfterPiP(restoring: false, airPlayActive: false), "Ordinary PiP close still pauses")
    }
}
