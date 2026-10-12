import Foundation

/// Preserve every signed URL field while replacing only a solved player challenge.
enum WebStreamURL {
    static func manifestChallenge(in url: URL) -> String? {
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .percentEncodedPath.components(separatedBy: "/") ?? []
        if let index = path.firstIndex(of: "n"), index + 1 < path.count {
            return path[index + 1].removingPercentEncoding
        }
        return challenge(in: url)
    }

    static func replacingManifestN(with value: String, in url: URL) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = encode(value), !value.isEmpty else {
                  return nil
              }
        var path = parts.percentEncodedPath.components(separatedBy: "/")
        guard let index = path.firstIndex(of: "n"), index + 1 < path.count else {
            return replacing("n", with: value, in: url)
        }
        path[index + 1] = encoded
        parts.percentEncodedPath = path.joined(separator: "/")
        return WebPlaybackProfile.mediaURL(parts.url?.absoluteString)
    }

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
        guard let encoded = encode(value) else {
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

    private static func encode(_ value: String) -> String? {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        ))
    }
}
