import Foundation

/// Uses only the YouTube session explicitly connected in this app. Main-thread owned.
final class YouTubeCommentClient {
    static let shared = YouTubeCommentClient()
    static let didChange = Notification.Name("youtubeCommentSessionDidChange")
    private let transport = YouTubeCommentTransport()
    private var session = YouTubeCommentStore.load()
    private var generation = 0

    var channel: CommentAPIChannel? { session?.channel }

    func connect(
        _ candidate: YouTubeCommentSession,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        generation += 1
        let expected = generation
        send("account/account_menu", body: [:], session: candidate) { [weak self] result in
            guard let self, self.generation == expected else {
                completion(.failure(CommentAPIError(reason: "cancelled")))
                return
            }
            completion(Result {
                var verified = candidate
                verified.channel = try YouTubeCommentModel.account(result.get())
                try YouTubeCommentStore.save(verified)
                self.session = verified
                NotificationCenter.default.post(name: Self.didChange, object: nil)
            })
        }
    }

    func cancelConnection() {
        generation += 1
    }

    func disconnect() {
        generation += 1
        session = nil
        YouTubeCommentStore.clear()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    /// Shares the selected website account, with the same cookie isolation as commenting.
    /// Discard replies from a connection that was replaced or disconnected in flight.
    func readNotifications(
        body: [String: Any],
        countOnly: Bool = false,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let session else {
            completion(.failure(YouTubeInboxError(reason: "signedOut")))
            return
        }
        let expected = generation
        let endpoint = countOnly
            ? "notification/get_unseen_count" : "notification/get_notification_menu"
        send(endpoint, body: body, session: session) { [weak self] result in
            guard self?.generation == expected else {
                completion(.failure(CommentAPIError(reason: "cancelled")))
                return
            }
            completion(result)
        }
    }

    func refreshProfile(completion: @escaping (CommentAPIChannel?) -> Void) {
        readSession("account/account_menu", body: [:]) { [weak self] result in
            guard let self, var session = self.session,
                  let profile = try? YouTubeCommentModel.account(result.get()) else {
                completion(self?.channel)
                return
            }
            session.channel = profile
            self.session = session
            try? YouTubeCommentStore.save(session)
            completion(profile)
        }
    }

    func readThread(
        videoID: String,
        commentID: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let token = InnertubeClient.buildCommentsContinuation(
            videoId: videoID, sortBy: 0, commentId: commentID
        )
        readSession("next", body: ["continuation": token], completion: completion)
    }

    func readComments(
        continuation: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        readSession("next", body: ["continuation": continuation], completion: completion)
    }

    private func readSession(
        _ endpoint: String,
        body: [String: Any],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let session else {
            completion(.failure(CommentAPIError(reason: "signedOut")))
            return
        }
        let expected = generation
        send(endpoint, body: body, session: session) { [weak self] result in
            guard self?.generation == expected else {
                completion(.failure(CommentAPIError(reason: "cancelled")))
                return
            }
            completion(result)
        }
    }

    func post(
        _ submission: CommentSubmission,
        completion: @escaping (Result<Comment, Error>) -> Void
    ) {
        guard let session else {
            completion(.failure(CommentAPIError(reason: "signedOut")))
            return
        }
        let expected = generation
        let token = InnertubeClient.buildCommentsContinuation(
            videoId: submission.target.videoID, sortBy: 0, commentId: submission.target.parentID
        )
        send("next", body: ["continuation": token], session: session) { [weak self] result in
            guard let self, self.generation == expected else {
                completion(.failure(CommentAPIError(reason: "cancelled")))
                return
            }
            self.submit(
                submission, page: result, expected: expected, completion: completion
            )
        }
    }

    private func submit(
        _ submission: CommentSubmission,
        page: Result<[String: Any], Error>,
        expected: Int,
        completion: @escaping (Result<Comment, Error>) -> Void
    ) {
        do {
            guard let session, expected == generation else {
                throw CommentAPIError(reason: "signedOut")
            }
            var body = try YouTubeCommentModel.writeBody(in: page.get(), target: submission.target)
            body["commentText"] = submission.text
            let endpoint = submission.target.parentID == nil
                ? "comment/create_comment" : "comment/create_comment_reply"
            send(endpoint, body: body, session: session) { result in
                // Do not retry or report cancellation after a write may have reached YouTube.
                completion(result.flatMap { json in
                    Result { try YouTubeCommentModel.createdComment(json) }
                })
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func send(
        _ endpoint: String,
        body: [String: Any],
        session: YouTubeCommentSession,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        do {
            guard let url = URL(string: "https://www.youtube.com/youtubei/v1/\(endpoint)") else {
                throw CommentAPIError(reason: "response")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpShouldHandleCookies = false
            request.allHTTPHeaderFields = try session.headers()
            var payload = body
            payload["context"] = try session.context()
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            transport.send(request, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

enum CommentPostingService {
    static var channel: CommentAPIChannel? {
        YouTubeCommentClient.shared.channel ?? CommentAPIClient.shared.channel
    }

    static func post(
        _ submission: CommentSubmission,
        completion: @escaping (Result<Comment, Error>) -> Void
    ) {
        if YouTubeCommentClient.shared.channel != nil {
            YouTubeCommentClient.shared.post(submission, completion: completion)
        } else {
            CommentAPIClient.shared.post(
                text: submission.text, target: submission.target, completion: completion
            )
        }
    }
}
