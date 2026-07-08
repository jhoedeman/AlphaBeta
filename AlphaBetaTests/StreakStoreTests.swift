import Testing
import Foundation
@testable import AlphaBeta

/// Exhaustive date-edge-case coverage for `StreakStore`, per SPEC §4's
/// explicit call-out: "same-day double quiz, gap day, DST, year boundary."
struct StreakStoreTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = hour
        return calendar.date(from: components)!
    }

    @Test func firstCompletionStartsStreakAtOne() {
        let store = StreakStore()
        let streak = store.recordCompletion(now: Self.date(2026, 1, 5), calendar: Self.calendar)
        #expect(streak == 1)
        #expect(store.currentStreak == 1)
        #expect(store.longestStreak == 1)
    }

    @Test func sameDayDoubleQuizDoesNotChangeStreak() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 1, 5, hour: 8), calendar: Self.calendar)
        let streak = store.recordCompletion(now: Self.date(2026, 1, 5, hour: 20), calendar: Self.calendar)
        #expect(streak == 1)
        #expect(store.currentStreak == 1)
    }

    @Test func consecutiveDaysExtendTheStreak() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 1, 5), calendar: Self.calendar)
        store.recordCompletion(now: Self.date(2026, 1, 6), calendar: Self.calendar)
        let streak = store.recordCompletion(now: Self.date(2026, 1, 7), calendar: Self.calendar)
        #expect(streak == 3)
        #expect(store.longestStreak == 3)
    }

    @Test func gapDayResetsStreakToOne() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 1, 5), calendar: Self.calendar)
        store.recordCompletion(now: Self.date(2026, 1, 6), calendar: Self.calendar)
        // Skips Jan 7 entirely.
        let streak = store.recordCompletion(now: Self.date(2026, 1, 8), calendar: Self.calendar)
        #expect(streak == 1)
        #expect(store.currentStreak == 1)
    }

    @Test func longestStreakSurvivesALaterBreak() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 1, 5), calendar: Self.calendar)
        store.recordCompletion(now: Self.date(2026, 1, 6), calendar: Self.calendar)
        store.recordCompletion(now: Self.date(2026, 1, 7), calendar: Self.calendar)
        // Gap, then restart — longestStreak should remember the earlier run of 3.
        store.recordCompletion(now: Self.date(2026, 1, 10), calendar: Self.calendar)
        #expect(store.currentStreak == 1)
        #expect(store.longestStreak == 3)
    }

    @Test func streakSurvivesSpringForwardDST() {
        // US spring-forward 2026-03-08: 2:00am -> 3:00am. Calendar-day math,
        // not raw 24h subtraction, must still see these as consecutive days.
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 3, 7, hour: 23), calendar: Self.calendar)
        let streak = store.recordCompletion(now: Self.date(2026, 3, 8, hour: 1), calendar: Self.calendar)
        #expect(streak == 2)
    }

    @Test func streakSurvivesFallBackDST() {
        // US fall-back 2026-11-01: 2:00am -> 1:00am (repeated hour).
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 10, 31, hour: 23), calendar: Self.calendar)
        let streak = store.recordCompletion(now: Self.date(2026, 11, 1, hour: 1), calendar: Self.calendar)
        #expect(streak == 2)
    }

    @Test func streakSurvivesYearBoundary() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2025, 12, 31), calendar: Self.calendar)
        let streak = store.recordCompletion(now: Self.date(2026, 1, 1), calendar: Self.calendar)
        #expect(streak == 2)
    }

    @Test func gapAcrossYearBoundaryResetsStreak() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2025, 12, 30), calendar: Self.calendar)
        // Skips Dec 31 entirely.
        let streak = store.recordCompletion(now: Self.date(2026, 1, 1), calendar: Self.calendar)
        #expect(streak == 1)
    }

    @Test func displayedStreakIsUnaffectedTheDayAfterCompletion() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 1, 5), calendar: Self.calendar)
        // It's now "yesterday" relative to the last completion — still alive,
        // pending today's quiz, so it should NOT read as 0 yet.
        let displayed = store.displayedStreak(now: Self.date(2026, 1, 6), calendar: Self.calendar)
        #expect(displayed == 1)
    }

    @Test func displayedStreakDropsToZeroAfterAMissedDayWithoutMutatingState() {
        let store = StreakStore()
        store.recordCompletion(now: Self.date(2026, 1, 5), calendar: Self.calendar)
        let displayed = store.displayedStreak(now: Self.date(2026, 1, 7), calendar: Self.calendar)
        #expect(displayed == 0)
        // Underlying state must be untouched until the next actual completion.
        #expect(store.currentStreak == 1)
        #expect(store.lastCompletedDay != nil)
    }

    @Test func displayedStreakBeforeAnyCompletionIsZero() {
        let store = StreakStore()
        #expect(store.displayedStreak(now: Self.date(2026, 1, 5), calendar: Self.calendar) == 0)
    }
}
