import Foundation

/// Preserve every signed URL field while replacing only a solved player challenge.
enum WebStreamURL {
    static func challenge(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "n" }?.value
    }

    static func replacing(_ name: String, with value: String, in url: URL) -> URL? {
        guard ["n", "sig", "signature", "lsig"].contains(name), !value.isEmpty,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        // Keep untouched fields byte-for-byte: queryItems can turn an encoded '+'
        // into a literal '+', which form-style servers interpret as a space.
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        var items = (parts.percentEncodedQuery ?? "").components(separatedBy: "&")
        items.removeAll {
            $0.isEmpty || $0.components(separatedBy: "=").first?.removingPercentEncoding == name
        }
        items.append("\(name)=\(encoded)")
        parts.percentEncodedQuery = items.joined(separator: "&")
        return WebPlaybackProfile.mediaURL(parts.url?.absoluteString)
    }
}
