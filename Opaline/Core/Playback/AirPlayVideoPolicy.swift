import Foundation

/// A receiver's decoder is independent of the phone's AV1 hardware support.
/// Use an AVC ladder through 1080p60 for AirPlay, without changing the
/// user's saved on-device quality preference or the selected playback source.
enum AirPlayVideoPolicy {
    static func isCompatible(_ format: DashFormatInfo) -> Bool {
        let codec = format.codecs.lowercased()
        guard codec.hasPrefix("avc1."),
              let level = Int(codec.suffix(2), radix: 16), level <= 42,
              let width = format.width, let height = format.height,
              width > 0, height > 0,
              max(width, height) <= 1_920, min(width, height) <= 1_080 else {
            return false
        }
        return (format.fps ?? 30) <= 60
    }

    /// Preserve a compatible choice. Never raise a lower quality selected by
    /// the user, and inspect the full ladder before labels hide codec siblings.
    static func replacement(
        for requested: DashFormatInfo,
        in formats: [DashFormatInfo]
    ) -> DashFormatInfo? {
        guard !isCompatible(requested) else {
            return requested
        }
        let compatible = formats.filter {
            isCompatible($0) && ($0.height ?? 0) <= (requested.height ?? 1_080)
        }
        return compatible.max { left, right in
            if left.height != right.height {
                return (left.height ?? 0) < (right.height ?? 0)
            }
            return left.bitrate < right.bitrate
        }
    }
}
