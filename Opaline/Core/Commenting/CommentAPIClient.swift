import AuthenticationServices
import UIKit

/// Independent of the TV playback login. All state and callbacks are main-thread owned.
final class CommentAPIClient: NSObject {
    static let shared = CommentAPIClient()
    static let didChange = Notification.Name("nativeCommentAccountDidChange")

    let transport: HTTPTransport = URLSessionTransport()
    var account: CommentAPIAccount? = CommentAccountStore.load()
    var generation = 0
    var authSession: ASWebAuthenticationSession?
    var authWindow: UIWindow?
    var refreshCallbacks: [(Result<String, Error>) -> Void] = []

    var channel: CommentAPIChannel? { account?.channel }
    var clientID: String {
        UserDefaults.standard.string(forKey: "nativeComments.clientID") ?? ""
    }

    func configure(clientID: String) throws {
        let value = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CommentOAuthRequest.validClientID(value) else {
            throw CommentAPIError(reason: "setup")
        }
        if self.clientID != value {
            disconnect()
            UserDefaults.standard.set(value, forKey: "nativeComments.clientID")
        }
    }

    func disconnect() {
        generation += 1
        authSession?.cancel()
        authSession = nil
        authWindow = nil
        account = nil
        CommentAccountStore.clear()
        finishRefresh(.failure(CommentAPIError(reason: "signedOut")))
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    func request(
        endpoint: String,
        token: String,
        query: [String: String]
    ) throws -> HTTPRequest {
        var url = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(endpoint)")
        url?.queryItems = query.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let url = url?.url else {
            throw CommentAPIError(reason: "response")
        }
        return HTTPRequest(
            method: .get,
            url: url,
            headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json"],
            timeout: 30,
            sendsCookies: false
        )
    }

    func sendJSON(
        _ request: HTTPRequest,
        isCommentWrite: Bool = false,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        transport.send(request, cancellationToken: nil) { result in
            let parsed: Result<[String: Any], Error> = Result {
                guard case .success(let response) = result else {
                    throw CommentAPIError(reason: isCommentWrite ? "uncertain" : "network")
                }
                if isCommentWrite, response.status >= 500 {
                    throw CommentAPIError(reason: "uncertain")
                }
                return try CommentAPIModel.json(data: response.data, status: response.status)
            }
            DispatchQueue.main.async { completion(parsed) }
        }
    }

    func fetchChannel(
        token: String,
        completion: @escaping (Result<CommentAPIChannel, Error>) -> Void
    ) {
        do {
            let request = try request(
                endpoint: "channels", token: token, query: ["part": "snippet", "mine": "true"]
            )
            sendJSON(request) { result in
                completion(result.flatMap { json in
                    let first = (json["items"] as? [[String: Any]])?.first
                    let snippet = first?["snippet"] as? [String: Any]
                    guard let id = first?["id"] as? String,
                          let title = snippet?["title"] as? String
                    else {
                        return .failure(CommentAPIError(reason: "noChannel"))
                    }
                    return .success(CommentAPIChannel(id: id, title: title))
                })
            }
        } catch {
            completion(.failure(error))
        }
    }
}
