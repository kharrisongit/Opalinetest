import Foundation
import Security

enum CommentAccountStore {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kharrisongit.opaline.native-comments",
            kSecAttrAccount as String: "google-oauth"
        ]
    }

    static func load() -> CommentAPIAccount? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(CommentAPIAccount.self, from: data)
    }

    static func save(_ account: CommentAPIAccount) throws {
        let data = try JSONEncoder().encode(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
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
