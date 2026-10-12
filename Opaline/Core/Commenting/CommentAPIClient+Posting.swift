import Foundation

extension CommentAPIClient {
    func post(
        text: String,
        target: CommentPostTarget,
        completion: @escaping (Result<Comment, Error>) -> Void
    ) {
        let current = generation
        validToken { result in
            guard self.generation == current else {
                completion(.failure(CommentAPIError(reason: "signedOut")))
                return
            }
            do {
                let token = try result.get()
                if target.parentID != nil {
                    self.insert(text: text, target: target, token: token, completion: completion)
                } else {
                    self.fetchVideoChannel(videoID: target.videoID, token: token) { result in
                        guard self.generation == current else {
                            completion(.failure(CommentAPIError(reason: "signedOut")))
                            return
                        }
                        self.insertTopLevel(
                            text: text,
                            target: target,
                            token: token,
                            channel: result,
                            completion: completion
                        )
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func fetchVideoChannel(
        videoID: String,
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        do {
            let request = try request(
                endpoint: "videos", token: token, query: ["part": "snippet", "id": videoID]
            )
            sendJSON(request) { result in
                completion(result.flatMap { json in
                    let first = (json["items"] as? [[String: Any]])?.first
                    let snippet = first?["snippet"] as? [String: Any]
                    guard let channel = snippet?["channelId"] as? String else {
                        return .failure(CommentAPIError(reason: "videoNotFound"))
                    }
                    return .success(channel)
                })
            }
        } catch {
            completion(.failure(error))
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func insertTopLevel(
        text: String,
        target: CommentPostTarget,
        token: String,
        channel: Result<String, Error>,
        completion: @escaping (Result<Comment, Error>) -> Void
    ) {
        do {
            try insertBody(
                target: target,
                token: token,
                body: target.body(text: text, channelID: try channel.get()),
                completion: completion
            )
        } catch {
            completion(.failure(error))
        }
    }

    private func insert(
        text: String,
        target: CommentPostTarget,
        token: String,
        completion: @escaping (Result<Comment, Error>) -> Void
    ) {
        do {
            try insertBody(
                target: target,
                token: token,
                body: target.body(text: text, channelID: nil),
                completion: completion
            )
        } catch {
            completion(.failure(error))
        }
    }

    private func insertBody(
        target: CommentPostTarget,
        token: String,
        body: [String: Any],
        completion: @escaping (Result<Comment, Error>) -> Void
    ) throws {
        var request = try request(
            endpoint: target.endpoint, token: token, query: ["part": "snippet"]
        )
        request.method = .post
        request.body = try JSONSerialization.data(withJSONObject: body)
        // Never retry a write automatically: a lost response may hide a successful post.
        sendJSON(request, isCommentWrite: true) { result in
            completion(result.flatMap { json in
                Result { try CommentAPIModel.createdComment(json, isReply: target.parentID != nil) }
            })
        }
    }
}
