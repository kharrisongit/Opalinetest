import Foundation

extension CommentAPIClient {
    func exchange(
        fields: [String: String],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            completion(.failure(CommentAPIError(reason: "setup")))
            return
        }
        let request = HTTPRequest(
            method: .post,
            url: url,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: CommentOAuthRequest.formBody(fields),
            timeout: 30,
            sendsCookies: false
        )
        sendJSON(request, completion: completion)
    }

    func validToken(completion: @escaping (Result<String, Error>) -> Void) {
        guard let account, account.tokens.clientID == clientID else {
            completion(.failure(CommentAPIError(reason: "signedOut")))
            return
        }
        if account.tokens.expires.timeIntervalSinceNow > 60 {
            completion(.success(account.tokens.accessToken))
            return
        }
        refreshCallbacks.append(completion)
        guard refreshCallbacks.count == 1 else {
            return
        }
        refresh(account)
    }

    private func refresh(_ previous: CommentAPIAccount) {
        let current = generation
        exchange(fields: [
            "client_id": previous.tokens.clientID,
            "refresh_token": previous.tokens.refreshToken,
            "grant_type": "refresh_token"
        ]) { result in
            guard self.generation == current else {
                return
            }
            let refreshed: Result<String, Error> = Result {
                let json = try result.get()
                let tokens = try CommentAPIModel.tokens(
                    json, clientID: previous.tokens.clientID, previous: previous.tokens
                )
                var updated = previous
                updated.tokens = tokens
                try CommentAccountStore.save(updated)
                self.account = updated
                return tokens.accessToken
            }
            self.finishRefresh(refreshed)
        }
    }

    func finishRefresh(_ result: Result<String, Error>) {
        let callbacks = refreshCallbacks
        refreshCallbacks = []
        for callback in callbacks {
            callback(result)
        }
    }
}
