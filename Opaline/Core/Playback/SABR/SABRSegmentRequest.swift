import Foundation

/// One segment as the client asks for it.
struct SABRSegmentRequest {
    let format: SabrFormatInfo
    /// The other stream, named so the server can be told not to send it.
    let other: SabrFormatInfo
    /// Segment number, counting from 1 as SABR does.
    let sequence: Int
    /// Where the segment starts in the video, which is where the server is
    /// asked to stream from. A seek is nothing more than a different value
    /// here — there is no separate seek request in this protocol.
    let timeMs: Int
    /// Init segments name a byte range of the opening; media segments take
    /// whatever the server sends for the sequence.
    let initRange: Int?

    var isInit: Bool { initRange != nil }

    /// A seek rounded down can land in the preceding segment.
    static func milliseconds(at seconds: Double) -> Int {
        Int((seconds * 1_000).rounded(.up))
    }
}
