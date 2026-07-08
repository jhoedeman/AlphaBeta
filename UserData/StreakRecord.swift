import Foundation
import SwiftData

/// Persisted counterpart to `StreakStore`'s in-memory state (SPEC §4),
/// singleton-by-convention (fetch first via `fetchOrCreateStreakRecord`,
/// else create).
@Model
final class StreakRecord {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCompletedDay: Date?

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastCompletedDay: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedDay = lastCompletedDay
    }

    /// CloudKit can duplicate a "singleton" model across devices before
    /// merges settle (SPEC §4) — reconcile to the candidate with the most
    /// recent `lastCompletedDay` (the most up-to-date streak/day pair),
    /// folding in the highest `longestStreak` seen across all candidates.
    static func merge(_ candidates: [StreakRecord]) -> StreakRecord {
        let longestStreak = candidates.map(\.longestStreak).max() ?? 0
        let winner = candidates.max { lhs, rhs in
            switch (lhs.lastCompletedDay, rhs.lastCompletedDay) {
            case let (l?, r?): return l < r
            case (nil, .some): return true
            default: return false
            }
        } ?? candidates[0]
        winner.longestStreak = longestStreak
        return winner
    }
}
