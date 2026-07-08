import Foundation
import SwiftData

/// SwiftData-backed bridge between the pure Quiz engine/view model and
/// CloudKit-synced user data (SPEC §4, M8) — the real replacement for
/// `NoOpAccuracyProvider`/`NoOpUserDataPersisting`. Snapshots the current
/// language's `ItemProgress` at init so quiz generation doesn't hit the
/// store once per candidate item.
final class SwiftDataUserDataStore: UserDataPersisting, ItemAccuracyProviding {
    private let context: ModelContext
    private var progressByItem: [Int: ItemProgress] = [:]

    init(context: ModelContext, languageID: Int) {
        self.context = context
        let descriptor = FetchDescriptor<ItemProgress>(
            predicate: #Predicate { $0.languageID == languageID }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for progress in existing {
            progressByItem[progress.itemIdentifier] = progress
        }
    }

    func accuracy(for itemIdentifier: Int) -> Double? {
        progressByItem[itemIdentifier]?.accuracy
    }

    func recordAnswer(languageID: Int, itemIdentifier: Int, isCorrect: Bool) {
        let progress: ItemProgress
        if let existing = progressByItem[itemIdentifier] {
            progress = existing
        } else {
            progress = ItemProgress(languageID: languageID, itemIdentifier: itemIdentifier)
            context.insert(progress)
            progressByItem[itemIdentifier] = progress
        }
        progress.timesQuizzed += 1
        if isCorrect { progress.timesCorrect += 1 }
        progress.lastQuizzedAt = .now
    }

    func recordQuizSession(
        languageID: Int, startedAt: Date, completedAt: Date,
        score: Int, questionCount: Int, filtersUsedRaw: String
    ) {
        let session = QuizSession(
            languageID: languageID, startedAt: startedAt, completedAt: completedAt,
            score: score, questionCount: questionCount, filtersUsedRaw: filtersUsedRaw
        )
        context.insert(session)
        try? context.save()
    }

    func persistStreak(currentStreak: Int, longestStreak: Int, lastCompletedDay: Date) {
        let record = context.fetchOrCreateStreakRecord()
        record.currentStreak = currentStreak
        record.longestStreak = longestStreak
        record.lastCompletedDay = lastCompletedDay
        try? context.save()
    }
}
