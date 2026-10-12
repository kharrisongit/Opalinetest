import Foundation

/// Main-thread gate: a timeout and a late network callback cannot both advance the chain.
struct PlaybackAttemptState {
    private(set) var generation = 0
    private var pending = false

    mutating func begin() -> Int {
        generation += 1
        pending = true
        return generation
    }

    mutating func finish(_ expected: Int) -> Bool {
        guard generation == expected, pending else {
            return false
        }
        pending = false
        return true
    }

    mutating func invalidate() {
        generation += 1
        pending = false
    }
}
