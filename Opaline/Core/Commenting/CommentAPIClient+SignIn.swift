import AuthenticationServices
import UIKit

extension CommentAPIClient {
    func signIn(
        from presenter: UIViewController,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard authSession == nil, let window = presenter.view.window else {
            completion(.failure(CommentAPIError(reason: "busy")))
            return
        }
        do {
            let request = try CommentOAuthRequest(clientID: clientID)
            let url = try request.authorizationURL()
            generation += 1
            finishRefresh(.failure(CommentAPIError(reason: "cancelled")))
            let current = generation
            authWindow = window
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: request.scheme
            ) { callback, _ in
                DispatchQueue.main.async {
                    self.finishSignIn(
                        callback: callback,
                        request: request,
                        generation: current,
                        completion: completion
                    )
                }
            }
            start(session, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    private func start(
        _ session: ASWebAuthenticationSession,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        authSession = session
        if #available(iOS 13.0, *) {
            session.presentationContextProvider = self
        }
        if !session.start() {
            authSession = nil
            authWindow = nil
            completion(.failure(CommentAPIError(reason: "busy")))
        }
    }

    private func finishSignIn(
        callback: URL?,
        request: CommentOAuthRequest,
        generation current: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard generation == current else {
            completion(.failure(CommentAPIError(reason: "cancelled")))
            return
        }
        authSession = nil
        authWindow = nil
        do {
            guard let callback else {
                throw CommentAPIError(reason: "cancelled")
            }
            let fields = try request.exchangeFields(callback: callback)
            exchange(fields: fields) { result in
                guard self.generation == current else {
                    completion(.failure(CommentAPIError(reason: "cancelled")))
                    return
                }
                do {
                    let tokens = try CommentAPIModel.tokens(
                        try result.get(), clientID: request.clientID
                    )
                    self.connect(tokens: tokens, generation: current, completion: completion)
                } catch {
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func connect(
        tokens: CommentAPITokens,
        generation current: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        fetchChannel(token: tokens.accessToken) { result in
            guard self.generation == current else {
                completion(.failure(CommentAPIError(reason: "cancelled")))
                return
            }
            do {
                let account = CommentAPIAccount(tokens: tokens, channel: try result.get())
                try CommentAccountStore.save(account)
                self.account = account
                NotificationCenter.default.post(name: Self.didChange, object: nil)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

@available(iOS 13.0, *)
extension CommentAPIClient: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        authWindow ?? ASPresentationAnchor()
    }
}
