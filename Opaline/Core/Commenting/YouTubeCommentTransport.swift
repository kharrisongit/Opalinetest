import Foundation

/// Dedicated, ephemeral transport: no logging, shared cookies, redirects or write retries.
final class YouTubeCommentTransport: NSObject, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func send(_ request: URLRequest, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let isWrite = request.url?.path.contains("/comment/") == true
        session.dataTask(with: request) { data, response, error in
            let result: Result<[String: Any], Error> = Result {
                guard error == nil, let data, let http = response as? HTTPURLResponse else {
                    throw CommentAPIError(reason: isWrite ? "uncertain" : "network")
                }
                return try CommentAPIModel.json(
                    data: data, status: http.statusCode, isCommentWrite: isWrite
                )
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    // swiftlint:disable:next function_parameter_count
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
