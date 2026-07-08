import Foundation

/// Pure streak computation per SPEC §4. In-memory for now — M8 swaps the
/// backing storage for a SwiftData `StreakRecord` without touching this
/// logic, since every method takes its `Date`/`Calendar` as a parameter.
@Observable
final class StreakStore {
    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var lastCompletedDay: Date?

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastCompletedDay: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedDay = lastCompletedDay
    }

    /// The streak to show in UI: the stored streak, unless a day (or more)
    /// was missed since the last completion, in which case it reads as 0
    /// without mutating `currentStreak` — that only happens on the next
    /// actual completion.
    func displayedStreak(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let lastCompletedDay else { return currentStreak }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return currentStreak }
        return lastCompletedDay < yesterday ? 0 : currentStreak
    }

    /// Call on quiz completion. Same-day repeat is a no-op; a completion
    /// exactly one calendar day after the last one extends the streak;
    /// anything else (a gap, or the very first completion) restarts it at 1.
    @discardableResult
    func recordCompletion(now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        defer { lastCompletedDay = today }

        guard let lastCompletedDay else {
            currentStreak = 1
            longestStreak = max(longestStreak, currentStreak)
            return currentStreak
        }
        let lastDay = calendar.startOfDay(for: lastCompletedDay)
        if lastDay == today {
            // Already credited today — no change.
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), lastDay == yesterday {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        longestStreak = max(longestStreak, currentStreak)
        return currentStreak
    }
}
