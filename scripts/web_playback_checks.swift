import AVFoundation
import Foundation

// Minimal dependencies for compiling the real fallback chain without the application UI.
protocol WatchService {}
struct TestWatchService: WatchService {}
struct PlaybackStep {
    let id: String
    let timeout: TimeInterval?
    let make: (WatchService) -> VideoSource
}
enum AppLog { static func player(_ value: String) {} }
enum PlaybackProgress { static func step(_ value: String) {} }
enum Failure: Error { case check(String) }

final class TestSource: VideoSource {
    let name: String
    let supportsQualitySelection = false
    let availableQualities: [VideoQuality] = []
    let currentQuality: VideoQuality? = nil
    var callbacks: [(Result<PreparedPlayback, Error>) -> Void] = []
    var releases = 0
    init(_ name: String) { self.name = name }
    func loadPlayback(videoId: String, cancellation: CancellationToken?,
                      completion: @escaping (Result<PreparedPlayback, Error>) -> Void) {
        callbacks.append(completion)
    }
    func selectQuality(_ quality: VideoQuality, resumeAt: Double?,
                       completion: @escaping (Result<PreparedPlayback, Error>) -> Void) {}
    func releaseResources() { releases += 1 }
    func success(_ index: Int = 0) {
        callbacks[index](.success(PreparedPlayback(item: AVPlayerItem(url: URL(fileURLWithPath: "/unused")))))
    }
}

@main enum WebPlaybackChecks {
    static var count = 0
    static let videoID = "aqz-KE-bpKQ"
    static func expect(_ test: Bool, _ message: String) throws {
        guard test else { throw Failure.check(message) }
        count += 1
    }
    static func rejects(_ block: () throws -> Void) throws {
        do { try block() } catch is WebPlaybackError { count += 1; return }
        throw Failure.check("Expected playback rejection")
    }
    static func pump(_ seconds: TimeInterval = 0.04) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
    static func main() throws {
        try configuration()
        try requests()
        try responses()
        try streamURLs()
        try chainRaces()
        print("Passed \(count) experimental playback checks")
    }
    static func configuration() throws {
        let html = #"ytcfg.set({"INNERTUBE_CLIENT_VERSION":"2.example","VISITOR_DATA":"visitor\u003d","STS":20512,"PLAYER_JS_URL":"\/s\/player\/test\/base.js"});"#
        let config = WebPlayerConfiguration(html: html)
        try expect(config.version == "2.example", "Read version from matching page")
        try expect(config.visitorData == "visitor=", "Decode JSON escapes")
        try expect(config.timestamp == 20512, "Read paired STS")
        try expect(config.scriptURL?.absoluteString == "https://www.youtube.com/s/player/test/base.js", "Relative JS")
        try expect(WebPlayerConfiguration.signatureTimestamp(in: "x={signatureTimestamp: 12345};") == 12345, "JS timestamp")
        try expect(WebPlayerConfiguration(html: "<html>consent</html>").timestamp == nil, "Never invent STS")
        for path in ["https://evil.invalid/s/player/x.js", "//evil.invalid/s/player/x.js",
                     "http://www.youtube.com/s/player/x.js", "https://www.youtube.com@evil.invalid/s/player/x.js",
                     "https://www.youtube.com:444/s/player/x.js", "/tv", "/s/player/../../private.js"] {
            try expect(WebPlayerConfiguration.validScriptURL(path) == nil, "Reject untrusted JS: \(path)")
        }
        try expect(WebPlayerConfiguration(html: #"{"jsUrl":"/s/player/x/base.js","sts":20513}"#).timestamp == 20513, "Alternate config names")
    }
    static func requests() throws {
        let config = WebPlayerConfiguration(html: #"{"INNERTUBE_CLIENT_VERSION":"2.test","VISITOR_DATA":"v","STS":42}"#)
        for profile in [WebPlaybackProfile.nativeHLS, .embedded] {
            let body = profile.body(videoID: videoID, config: config)
            let request = try WebPlaybackRequest.make(body)
            try expect(request.url?.host == "www.youtube.com" && request.httpMethod == "POST", "Fixed YouTube read endpoint")
            try expect(!request.httpShouldHandleCookies, "No shared cookies")
            try expect(request.value(forHTTPHeaderField: "Cookie") == nil && request.value(forHTTPHeaderField: "Authorization") == nil, "Anonymous baseline")
            try expect(request.value(forHTTPHeaderField: "X-Youtube-Client-Name") == profile.headerName, "Matching profile header")
            try expect(request.value(forHTTPHeaderField: "X-Youtube-Client-Version") == "2.test", "Dynamic version header")
            let context = body["context"] as! [String: Any]
            let client = context["client"] as! [String: Any]
            try expect(client["clientName"] as? String == profile.clientName, "Matching body client")
            try expect(client["browserName"] as? String == "Safari", "HLS-capable web profile")
            try expect(body["serviceIntegrityDimensions"] == nil, "No reused/fabricated token")
            try expect((context["thirdParty"] != nil) == (profile == .embedded), "Embed context only for embed route")
            try expect(try profile.pageURL(videoID: videoID).host == "www.youtube.com", "Fixed bootstrap host")
            try rejects { _ = try profile.pageURL(videoID: "../evil?x=1") }
        }
    }
    static func responses() throws {
        let good: [String: Any] = ["playabilityStatus": ["status": "OK"], "videoDetails": ["videoId": videoID], "streamingData": ["hlsManifestUrl": "https://manifest.googlevideo.com/master.m3u8"]]
        try expect(try WebPlaybackProfile.streamingData(good, videoID: videoID)["hlsManifestUrl"] != nil, "Accept intended playable response")
        for status in ["LOGIN_REQUIRED", "UNPLAYABLE", "ERROR", "AGE_CHECK_REQUIRED"] {
            var restricted = good
            restricted["playabilityStatus"] = ["status": status]
            try rejects { _ = try WebPlaybackProfile.streamingData(restricted, videoID: videoID) }
        }
        try rejects { _ = try WebPlaybackProfile.streamingData(good, videoID: "differentid") }
        var drm = good
        drm["streamingData"] = ["licenseInfos": [["drmFamily": "WIDEVINE"]]]
        try rejects { _ = try WebPlaybackProfile.streamingData(drm, videoID: videoID) }
        try expect(WebPlaybackProfile.isHLS("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nvariant.m3u8\n"), "Master playlist")
        try expect(WebPlaybackProfile.isHLS("#EXTM3U\n#EXTINF:6,\nsegment.ts\n"), "Media playlist")
        for invalid in ["<html>blocked</html>", "#EXTM3U", "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\n"] {
            try expect(!WebPlaybackProfile.isHLS(invalid), "Reject empty/non-HLS response")
        }
    }
    static func streamURLs() throws {
        for value in ["http://r.googlevideo.com/v", "https://googlevideo.com.evil.invalid/v", "file:///tmp/a",
                      "https://googlevideo.com@evil.invalid/v", "https://r.googlevideo.com:444/v", "https://youtube.com/watch"] {
            try expect(WebPlaybackProfile.mediaURL(value) == nil, "Reject non-CDN URL")
        }
        let url = URL(string: "https://r.googlevideo.com/videoplayback?n=abc&cver=2.test&pot=bound%2Btoken&signature=old&expire=99")!
        let solved = WebStreamURL.replacing("signature", with: "a+b/c=", in: url)!
        let final = WebStreamURL.replacing("n", with: "solved", in: solved)!
        let items = URLComponents(url: final, resolvingAgainstBaseURL: false)!.queryItems!
        try expect(WebStreamURL.challenge(in: final) == "solved", "Replace n challenge")
        try expect(items.first { $0.name == "signature" }?.value == "a+b/c=", "Encode solved signature")
        try expect(items.filter { $0.name == "signature" }.count == 1, "No duplicate signature")
        try expect(items.first { $0.name == "pot" }?.value == "bound+token", "Keep original bound token")
        try expect(items.first { $0.name == "cver" }?.value == "2.test", "Keep original client version")
        try expect(items.first { $0.name == "expire" }?.value == "99", "Keep signed expiry")
        try expect(final.absoluteString.contains("pot=bound%2Btoken"), "Preserve original query encoding")
        try expect(final.absoluteString.contains("signature=a%2Bb%2Fc%3D"), "Encode plus and slash in new signatures")
        try expect(WebStreamURL.replacing("expire", with: "100", in: url) == nil, "Cannot modify unrelated fields")
        try expect(WebStreamURL.replacing("n", with: "", in: url) == nil, "Reject empty solve")
    }
    static func chainRaces() throws {
        let first = TestSource("first"), second = TestSource("second")
        let chain = FallbackChainSource(steps: [
            PlaybackStep(id: "first", timeout: 0.02, make: { _ in first }),
            PlaybackStep(id: "second", timeout: 1, make: { _ in second })
        ], apiClient: TestWatchService())
        var results = 0
        chain.loadPlayback(videoId: videoID, cancellation: nil) { _ in results += 1 }
        pump(0.1)
        try expect(second.callbacks.count == 1 && first.releases == 1, "Timeout advances and releases once")
        first.success()
        first.callbacks[0](.failure(WebPlaybackError.unavailable))
        second.success()
        second.success()
        pump()
        try expect(results == 1 && chain.name == "second", "Late/duplicate callbacks cannot replace winning source")
        chain.loadPlayback(videoId: videoID, cancellation: nil) { _ in results += 1 }
        chain.releaseResources()
        first.success(1)
        pump(0.1)
        try expect(results == 1 && second.callbacks.count == 1 && chain.active == nil, "Release cancels timeout and stale completion")
        let token = CancellationToken()
        chain.loadPlayback(videoId: videoID, cancellation: token) { _ in results += 1 }
        token.cancel()
        first.success(2)
        pump(0.1)
        try expect(results == 1 && second.callbacks.count == 1, "Cancellation cannot advance or deliver success")
        chain.releaseResources()
        var gate = PlaybackAttemptState()
        let old = gate.begin(), current = gate.begin()
        try expect(!gate.finish(old) && gate.finish(current) && !gate.finish(current), "Only newest attempt can finish once")
    }
}
