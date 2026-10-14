import Foundation

protocol PoTokenProvider: AnyObject {
    func fetchSessionToken(
        identifier: String,
        client: String,
        completion: @escaping (Result<String, Error>) -> Void
    )
    func invalidateToken(identifier: String, client: String)
}

/// Fetches proof-of-origin tokens from the configured provider. Cache entries,
/// in-flight requests and forced refreshes all use the same client/binding key.
final class RemotePoTokenService: PoTokenProvider {
    enum ProviderError: Error {
        case notConfigured
        case badResponse
        case invalidated
    }

    private struct CachedMint {
        let token: String
        let minted: Date
    }

    private struct PendingMint {
        let id: UUID
        let cancellation: CancellationToken
        var waiters: [(Result<String, Error>) -> Void]
    }

    static let shared = RemotePoTokenService()
    private static let tokenTTL: TimeInterval = 30 * 60
    private let transport: HTTPTransport
    private var cache: [String: CachedMint] = [:]
    private var bypassProviderCache: Set<String> = []
    private var inFlight: [String: PendingMint] = [:]
    private let lock = NSLock()

    init(transport: HTTPTransport = ServiceContainer.transport) {
        self.transport = transport
    }

    func fetchSessionToken(
        identifier: String,
        client: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let key = "\(client)|\(identifier)"
        lock.lock()
        if let cached = cache[key], Date().timeIntervalSince(cached.minted) < Self.tokenTTL {
            lock.unlock()
            completion(.success(cached.token))
            return
        }
        if inFlight[key] != nil {
            inFlight[key]?.waiters.append(completion)
            lock.unlock()
            return
        }
        let pending = PendingMint(
            id: UUID(), cancellation: CancellationToken(), waiters: [completion]
        )
        inFlight[key] = pending
        let bypass = bypassProviderCache.contains(key)
        lock.unlock()
        request(identifier: identifier, client: client, bypass: bypass, pending: pending)
    }

    func invalidateToken(identifier: String, client: String) {
        let key = "\(client)|\(identifier)"
        lock.lock()
        cache[key] = nil
        bypassProviderCache.insert(key)
        let pending = inFlight.removeValue(forKey: key)
        lock.unlock()
        pending?.cancellation.cancel()
        pending?.waiters.forEach { $0(.failure(ProviderError.invalidated)) }
        AppLog.poToken("discarded rejected token for \(client)")
    }
}

extension RemotePoTokenService {
    private static func parse(_ response: HTTPResponse) -> Result<String, Error> {
        guard (200 ... 299).contains(response.status),
              let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let token = (json["poToken"] ?? json["po_token"]) as? String,
              !token.isEmpty, !token.hasPrefix("ERR:") else {
            return .failure(ProviderError.badResponse)
        }
        return .success(token)
    }

    private func request(identifier: String, client: String, bypass: Bool, pending: PendingMint) {
        let key = "\(client)|\(identifier)"
        guard let endpoint = AppURLs.PoTokenProvider.endpoint else {
            finish(key: key, id: pending.id, result: .failure(ProviderError.notConfigured))
            return
        }
        var payload: [String: Any] = ["content_binding": identifier, "client": client]
        if bypass { payload["bypass_cache"] = true }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            finish(key: key, id: pending.id, result: .failure(ProviderError.badResponse))
            return
        }
        let request = HTTPRequest(
            method: .post,
            url: endpoint,
            headers: [HTTPHeader.contentType: HTTPHeaderValue.contentTypeJSON],
            body: body,
            timeout: 15,
            sendsCookies: false,
            isPlayback: true
        )
        AppLog.poToken("requesting token for \(client), refresh=\(bypass)")
        transport.send(request, cancellationToken: pending.cancellation) { [weak self] result in
            self?.finish(key: key, id: pending.id, result: result.flatMap(Self.parse))
        }
    }

    private func finish(key: String, id: UUID, result: Result<String, Error>) {
        lock.lock()
        guard let pending = inFlight[key], pending.id == id else {
            lock.unlock()
            return
        }
        inFlight[key] = nil
        if case .success(let token) = result {
            cache[key] = CachedMint(token: token, minted: Date())
            bypassProviderCache.remove(key)
        }
        lock.unlock()
        pending.waiters.forEach { $0(result) }
    }
}
