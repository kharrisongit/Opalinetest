import Foundation

/// A lightweight cancellation token for coordinating cancellation of
/// async operations that use completion handlers (pre-Swift-Concurrency).
///
/// Usage:
///   let token = CancellationToken()
///   apiClient.fetch(..., cancellationToken: token) { result in ... }
///   token.cancel()  // all registered tasks are cancelled, callbacks are silenced
final class CancellationToken {
    private let lock = NSLock()
    private var tasks: [URLSessionDataTask] = []
    private var children: [CancellationToken] = []
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let pending = tasks
        let pendingChildren = children
        tasks = []
        children = []
        lock.unlock()
        pending.forEach { $0.cancel() }
        pendingChildren.forEach { $0.cancel() }
    }

    /// A fallback step can be cancelled without cancelling the entire load.
    /// Cancelling the load still cancels every step registered beneath it.
    func register(_ token: CancellationToken) {
        guard token !== self else {
            return
        }
        lock.lock()
        if cancelled {
            lock.unlock()
            token.cancel()
        } else {
            children.append(token)
            lock.unlock()
        }
    }

    func register(_ task: URLSessionDataTask) {
        lock.lock()
        if cancelled {
            lock.unlock()
            task.cancel()
        } else {
            tasks.append(task)
            lock.unlock()
        }
    }
}
