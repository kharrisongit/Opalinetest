import Foundation
import Security

enum YouTubeCommentStore {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kharrison.utube.comment-session",
            kSecAttrAccount as String: "youtube-website"
        ]
    }

    static func load() -> YouTubeCommentSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(YouTubeCommentSession.self, from: data)
    }

    static func save(_ session: YouTubeCommentSession) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(session),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = query.merging(attributes) { _, new in new }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw CommentAPIError(reason: "storage")
            }
        } else if status != errSecSuccess {
            throw CommentAPIError(reason: "storage")
        }
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}
