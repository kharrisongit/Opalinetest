import Foundation

/// What the last response delivered for one stream.
///
/// This is what a request acknowledges, and it is deliberately *not* a running
/// total: the server tracks the whole picture itself through the playback
/// cookie, and only needs to hear which segments just landed. Claiming
/// everything from zero instead — as this once did — states that the bytes
/// behind the playhead are already held, so the server never sends them again
/// and rewinding cannot work at all.
struct SABRBufferedRange {
    let format: SabrFormatInfo
    let startMs: Int
    let durationMs: Int
    let startSequence: Int
    let endSequence: Int
    let timescale: Int

    /// MediaHeader normalizes timestamps to milliseconds. Sending the original
    /// timescale alongside those values would describe a different interval.
    var timeRange: Data {
        Protobuf.int(1, startMs) + Protobuf.int(2, durationMs) + Protobuf.int(3, 1_000)
    }

    /// A retry needs those bytes again, even if an earlier request got them.
    func acknowledged(for request: SABRSegmentRequest) -> SABRBufferedRange? {
        request.isInit || endSequence >= request.sequence ? nil : self
    }
}
