import CommonCrypto
import Foundation
import Security

struct CommentOAuthRequest {
    static let scope = "https://www.googleapis.com/auth/youtube.force-ssl"

    let clientID: String
    let verifier: String
    let state: String

    var scheme: String { clientID.split(separator: ".").reversed().joined(separator: ".") }
    var redirect: String { "\(scheme):/oauth2redirect" }

    init(clientID: String) throws {
        guard Self.validClientID(clientID) else {
            throw CommentAPIError(reason: "setup")
        }
        self.clientID = clientID
        verifier = try Self.randomValue()
        state = try Self.randomValue()
    }

    static func validClientID(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$"#,
            options: .regularExpression
        ) != nil
    }

    static func challenge(_ verifier: String) -> String {
        let data = Data(verifier.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest) }
        return base64URL(Data(digest))
    }

    static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        let sorted = fields.sorted { $0.key < $1.key }
        let components = sorted.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }
        return Data(components.joined(separator: "&").utf8)
    }

    private static func randomValue() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CommentAPIError(reason: "callback")
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    func authorizationURL() throws -> URL {
        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        url?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.challenge(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent select_account")
        ]
        guard let result = url?.url else {
            throw CommentAPIError(reason: "setup")
        }
        return result
    }

    func exchangeFields(callback: URL) throws -> [String: String] {
        let url = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let query = url?.queryItems ?? []
        guard url?.scheme == scheme, url?.host == nil,
              url?.path == "/oauth2redirect", url?.fragment == nil,
              query.filter({ $0.name == "state" }).count == 1,
              query.first(where: { $0.name == "state" })?.value == state
        else {
            throw CommentAPIError(reason: "callback")
        }
        if query.contains(where: { $0.name == "error" }) {
            throw CommentAPIError(reason: "cancelled")
        }
        guard query.filter({ $0.name == "code" }).count == 1,
              let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty
        else {
            throw CommentAPIError(reason: "callback")
        }
        return [
            "client_id": clientID, "code": code, "code_verifier": verifier,
            "grant_type": "authorization_code", "redirect_uri": redirect
        ]
    }
}
