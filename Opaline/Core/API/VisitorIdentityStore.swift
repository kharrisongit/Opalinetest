import Foundation

/// Owns anonymous visitor state. Preflights never mutate URLSession's cookie jar;
/// only a response from the current generation can commit visitor data/cookies.
final class VisitorIdentityStore {
    static let shared = VisitorIdentityStore()
    static let didReset = Notification.Name("uTubeVisitorIdentityReset")
    private let lock = NSRecursiveLock()
    private var epoch = 0
    private var scope = CancellationToken()
    private var fetching = false
    private var waiters: [(String?) -> Void] = []
    private let defaults: UserDefaults
    private let cookies: HTTPCookieStorage
    private let transport: HTTPTransport

    var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return epoch
    }

    var visitorData: String? {
        lock.lock()
        defer { lock.unlock() }
        guard let date = defaults.object(
            forKey: UserDefaultsKeys.Innertube.visitorDataDate
        ) as? Date, Date().timeIntervalSince(date) < 24 * 60 * 60 else {
            return nil
        }
        return defaults.string(forKey: UserDefaultsKeys.Innertube.visitorData)
    }

    init(
        defaults: UserDefaults = .standard,
        cookies: HTTPCookieStorage = .shared,
        transport: HTTPTransport = ServiceContainer.transport
    ) {
        self.defaults = defaults
        self.cookies = cookies
        self.transport = transport
    }

    func childToken(parent: CancellationToken?) -> CancellationToken {
        lock.lock()
        defer { lock.unlock() }
        let child = CancellationToken()
        parent?.register(child)
        scope.register(child)
        return child
    }

    func fetch(_ request: HTTPRequest, completion: @escaping (String?) -> Void) {
        lock.lock()
        if let value = visitorData {
            lock.unlock()
            completion(value)
            return
        }
        waiters.append(completion)
        guard !fetching else {
            lock.unlock()
            return
        }
        fetching = true
        let expected = epoch
        let token = scope
        lock.unlock()
        transport.send(request, cancellationToken: token) { [weak self] result in
            self?.finish(result, url: request.url, expected: expected)
        }
    }

    func reset(notify: Bool = true) {
        lock.lock()
        epoch += 1
        let old = scope
        scope = CancellationToken()
        waiters = []
        fetching = false
        defaults.removeObject(forKey: UserDefaultsKeys.Innertube.visitorData)
        defaults.removeObject(forKey: UserDefaultsKeys.Innertube.visitorDataDate)
        cookies.cookies?.filter(Self.isVisitorCookie).forEach(cookies.deleteCookie)
        lock.unlock()
        old.cancel()
        if notify {
            NotificationCenter.default.post(name: Self.didReset, object: nil)
        }
    }

    /// Called only after the user chooses Retry in the visible verification view.
    func adopt(visitor: String, browserCookies: [HTTPCookie]) -> Bool {
        guard !visitor.isEmpty, visitor.count <= 16_384,
              browserCookies.contains(where: Self.isVisitorCookie) else {
            return false
        }
        lock.lock()
        reset(notify: false)
        save(visitor: visitor, received: browserCookies)
        lock.unlock()
        return true
    }

    static func isVisitorCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return ["youtube.com", "www.youtube.com", "m.youtube.com"].contains(domain)
            && cookie.name.hasPrefix("VISITOR_")
            && (cookie.expiresDate.map { $0 > Date() } ?? true)
    }

    private func finish(_ result: Result<HTTPResponse, Error>, url: URL, expected: Int) {
        lock.lock()
        guard expected == epoch else {
            lock.unlock()
            return
        }
        var value: String?
        if case .success(let response) = result, (200 ... 299).contains(response.status) {
            value = InnertubeClient.extractVisitorData(from: response.data)
            if let value {
                save(visitor: value, received: HTTPCookie.cookies(
                    withResponseHeaderFields: response.headers, for: url
                ))
            }
        }
        let callbacks = waiters
        waiters = []
        fetching = false
        lock.unlock()
        callbacks.forEach { $0(value) }
    }

    private func save(visitor: String, received: [HTTPCookie]) {
        defaults.set(visitor, forKey: UserDefaultsKeys.Innertube.visitorData)
        defaults.set(Date(), forKey: UserDefaultsKeys.Innertube.visitorDataDate)
        received.filter(Self.isVisitorCookie).forEach(cookies.setCookie)
    }
}
