import Foundation

// MARK: - Direct Playback Response Parsing

extension InnertubeClient {
    static func parseDirectPlayback(
        json: [String: Any],
        videoId: String,
        client: PlaybackClient,
        onBotCheck: () -> Void
    ) -> DirectPlaybackInfo? {
        guard let info = parseDirectPlaybackInfo(json) else {
            logDirectPlaybackError(
                json: json,
                videoId: videoId,
                client: client
            )
            if isBotCheck(json) {
                onBotCheck()
            }
            return nil
        }
        let hlsFlag = info.hlsManifestURL != nil
        let progFlag = info.progressiveURL != nil
        let avFlag = info.videoURL != nil && info.audioURL != nil
        AppLog.innertube(
            "directPlayback selected (\(client)) \(videoId): "
                + "hls=\(hlsFlag) prog=\(progFlag) v+a=\(avFlag)"
        )
        return info
    }

    static func isBotCheck(_ json: [String: Any]) -> Bool {
        PlaybackFailure.isBotCheck(json)
    }

    static func logDirectPlaybackError(
        json: [String: Any],
        videoId: String,
        client: PlaybackClient
    ) {
        if let errorObj = json["error"],
           let data = try? JSONSerialization.data(
               withJSONObject: errorObj,
               options: .prettyPrinted
           ),
           let str = String(data: data, encoding: .utf8) {
            AppLog.innertube(
                "directPlayback error (\(client.name)): \(str)"
            )
        }
        logPlayerDebug(
            videoId: videoId,
            contextName: client.name,
            json: json
        )
    }
}
