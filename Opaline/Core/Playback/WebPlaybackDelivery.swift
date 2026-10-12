import Foundation

/// Delivery is independent of the requesting client. Embedded web can supply either kind.
enum WebPlaybackDelivery {
    case nativeHLS
    case byteRanges

    /// The input has already had signatureCipher URLs unwrapped by the existing parser.
    func streamingData(from data: [String: Any]) throws -> [String: Any] {
        switch self {
        case .nativeHLS:
            guard let url = WebPlaybackProfile.mediaURL(data["hlsManifestUrl"] as? String) else {
                throw WebPlaybackError.unavailable
            }
            return ["hlsManifestUrl": url.absoluteString]
        case .byteRanges:
            let formats = (data["adaptiveFormats"] as? [[String: Any]] ?? []).filter {
                WebPlaybackProfile.mediaURL($0["url"] as? String) != nil && $0["drmFamilies"] == nil
            }
            guard !formats.isEmpty else {
                throw WebPlaybackError.unavailable
            }
            return ["adaptiveFormats": formats]
        }
    }
}
