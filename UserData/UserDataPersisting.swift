import Foundation

/// Persistence facade the Quiz feature writes through, mirroring the
/// read-side split already established by `ItemAccuracyProviding` — keeps
/// `QuizViewModel` unit-testable without a `ModelContext` (SPEC §4).
protocol UserDataPersisting {
    func recordAnswer(languageID: Int, itemIdentifier: Int, isCorrect: Bool)
    func recordQuizSession(
        languageID: Int, startedAt: Date, completedAt: Date,
        score: Int, questionCount: Int, filtersUsedRaw: String
    )
    func persistStreak(currentStreak: Int, longestStreak: Int, lastCompletedDay: Date)
}

/// Default for previews/tests — the M6/M7 behavior before SwiftData was wired up.
struct NoOpUserDataPersisting: UserDataPersisting {
    func recordAnswer(languageID: Int, itemIdentifier: Int, isCorrect: Bool) {}
    func recordQuizSession(
        languageID: Int, startedAt: Date, completedAt: Date,
        score: Int, questionCount: Int, filtersUsedRaw: String
    ) {}
    func persistStreak(currentStreak: Int, longestStreak: Int, lastCompletedDay: Date) {}
}
