import Foundation

/// Only explicit evidence triggers session recovery. A generic 403 is a stream
/// refusal, not proof that a visitor or account is a bot.
enum PlaybackFailure: LocalizedError, Equatable {
    case botCheck
    case tokenRejected
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .botCheck:
            return "player.error.botCheck".localized
        case .tokenRejected:
            return "player.error.playback".localized
        case .rateLimited:
            return "player.error.cooldown".localized
        }
    }

    static func isBotCheck(_ json: [String: Any]) -> Bool {
        guard let status = json["playabilityStatus"] as? [String: Any],
              let code = status["status"] as? String,
              ["LOGIN_REQUIRED", "UNPLAYABLE", "ERROR"].contains(code),
              let data = try? JSONSerialization.data(withJSONObject: status),
              let text = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return ["not a bot", "unusual traffic", "confirm you’re human", "confirm you're human"]
            .contains { text.contains($0) }
    }
}

/// One automatic identity refresh per load, followed by an explicit user action.
/// The cooldown is shared across videos so changing videos cannot restart a burst.
final class PlaybackRecoveryGate {
    static let shared = PlaybackRecoveryGate()
    private let lock = NSLock()
    private var nextAttempt = Date.distantPast
    private var blockedUntil = Date.distantPast

    func claim(now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard now >= nextAttempt else {
            return false
        }
        nextAttempt = now.addingTimeInterval(30)
        return true
    }

    func delay(now: Date = Date()) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return max(0, blockedUntil.timeIntervalSince(now))
    }

    func rateLimited(now: Date = Date()) {
        lock.lock()
        blockedUntil = max(blockedUntil, now.addingTimeInterval(30))
        nextAttempt = max(nextAttempt, blockedUntil)
        lock.unlock()
    }
}
