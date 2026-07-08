import Testing
import Foundation
import SwiftData
@testable import AlphaBeta

/// M8: singleton fetch-and-merge, and the `SwiftDataUserDataStore` bridge
/// between the pure Quiz view model and SwiftData (SPEC §4).
struct UserDataPersistenceTests {
    private static func makeContext() -> ModelContext {
        let schema = Schema([UserPreferences.self, ItemProgress.self, QuizSession.self, StreakRecord.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    // MARK: - Singleton fetch-and-merge

    @Test func fetchOrCreateStreakRecordCreatesOneWhenNoneExist() {
        let context = Self.makeContext()
        let record = context.fetchOrCreateStreakRecord()
        #expect(record.currentStreak == 0)
        #expect((try? context.fetch(FetchDescriptor<StreakRecord>()))?.count == 1)
    }

    @Test func fetchOrCreateStreakRecordReturnsExistingSingleton() {
        let context = Self.makeContext()
        let existing = StreakRecord(currentStreak: 5, longestStreak: 9, lastCompletedDay: Date(timeIntervalSince1970: 100))
        context.insert(existing)

        let fetched = context.fetchOrCreateStreakRecord()
        #expect(fetched === existing)
        #expect(fetched.currentStreak == 5)
    }

    @Test func fetchOrCreateStreakRecordMergesDuplicatesKeepingMostRecentDayAndHighestLongestStreak() {
        let context = Self.makeContext()
        let stale = StreakRecord(currentStreak: 2, longestStreak: 10, lastCompletedDay: Date(timeIntervalSince1970: 100))
        let fresh = StreakRecord(currentStreak: 3, longestStreak: 4, lastCompletedDay: Date(timeIntervalSince1970: 200))
        context.insert(stale)
        context.insert(fresh)

        let winner = context.fetchOrCreateStreakRecord()
        #expect(winner === fresh)
        #expect(winner.currentStreak == 3)
        #expect(winner.longestStreak == 10)
        #expect((try? context.fetch(FetchDescriptor<StreakRecord>()))?.count == 1)
    }

    @Test func fetchOrCreateUserPreferencesDedupesDuplicatesToOneSurvivor() {
        let context = Self.makeContext()
        let first = UserPreferences(selectedLanguageID: 1)
        let second = UserPreferences(selectedLanguageID: 2)
        context.insert(first)
        context.insert(second)

        // SwiftData doesn't guarantee fetch order, so the merge policy just
        // needs to leave exactly one (either) survivor, not a specific one.
        let winner = context.fetchOrCreateUserPreferences()
        #expect(winner === first || winner === second)
        #expect((try? context.fetch(FetchDescriptor<UserPreferences>()))?.count == 1)
    }

    // MARK: - SwiftDataUserDataStore

    @Test func recordAnswerCreatesItemProgressAndAccumulates() {
        let context = Self.makeContext()
        let store = SwiftDataUserDataStore(context: context, languageID: 1)

        store.recordAnswer(languageID: 1, itemIdentifier: 42, isCorrect: true)
        store.recordAnswer(languageID: 1, itemIdentifier: 42, isCorrect: false)

        #expect(store.accuracy(for: 42) == 0.5)
        let progress = (try? context.fetch(FetchDescriptor<ItemProgress>()))?.first
        #expect(progress?.timesQuizzed == 2)
        #expect(progress?.timesCorrect == 1)
    }

    @Test func accuracyIsNilForAnUnseenItem() {
        let context = Self.makeContext()
        let store = SwiftDataUserDataStore(context: context, languageID: 1)
        #expect(store.accuracy(for: 99) == nil)
    }

    @Test func storeInitLoadsExistingProgressForTheGivenLanguageOnly() {
        let context = Self.makeContext()
        context.insert(ItemProgress(languageID: 1, itemIdentifier: 1, timesQuizzed: 4, timesCorrect: 4))
        context.insert(ItemProgress(languageID: 2, itemIdentifier: 1, timesQuizzed: 4, timesCorrect: 0))

        let store = SwiftDataUserDataStore(context: context, languageID: 1)
        #expect(store.accuracy(for: 1) == 1.0)
    }

    @Test func recordQuizSessionInsertsASession() {
        let context = Self.makeContext()
        let store = SwiftDataUserDataStore(context: context, languageID: 1)
        store.recordQuizSession(
            languageID: 1, startedAt: .now, completedAt: .now,
            score: 8, questionCount: 10, filtersUsedRaw: "capitals,lowercase"
        )
        let sessions = (try? context.fetch(FetchDescriptor<QuizSession>())) ?? []
        #expect(sessions.count == 1)
        #expect(sessions.first?.score == 8)
    }

    @Test func persistStreakWritesThroughToTheSingletonRecord() {
        let context = Self.makeContext()
        let store = SwiftDataUserDataStore(context: context, languageID: 1)
        let day = Date(timeIntervalSince1970: 500)

        store.persistStreak(currentStreak: 3, longestStreak: 3, lastCompletedDay: day)

        let record = context.fetchOrCreateStreakRecord()
        #expect(record.currentStreak == 3)
        #expect(record.longestStreak == 3)
        #expect(record.lastCompletedDay == day)
    }

    // MARK: - UserPreferencesStore (M9)

    @Test func preferencesStoreLoadsDefaultsWhenNoRecordExists() {
        let context = Self.makeContext()
        let store = UserPreferencesStore(context: context)
        #expect(store.selectedLanguageID == 0)
        #expect(store.appearanceRaw == "system")
        #expect(store.paletteID == "")
        #expect(store.cardFilterRaw == "")
        #expect(store.isShuffled == false)
    }

    @Test func preferencesStoreSettersPersistToTheSingletonRecord() {
        let context = Self.makeContext()
        let store = UserPreferencesStore(context: context)

        store.setSelectedLanguage(id: 7)
        store.setPronunciationSystem(id: "western")
        store.setAppearance("dark")
        store.setPalette(id: "russian-flag")
        store.setCardPreferences(filterRaw: "capitals,lowercase", isShuffled: true)

        #expect(store.selectedLanguageID == 7)
        #expect(store.pronunciationSystemID == "western")
        #expect(store.appearanceRaw == "dark")
        #expect(store.paletteID == "russian-flag")
        #expect(store.cardFilterRaw == "capitals,lowercase")
        #expect(store.isShuffled == true)

        // Reloading from a fresh store over the same context proves the
        // record itself was updated, not just the in-memory mirror.
        let reloaded = UserPreferencesStore(context: context)
        #expect(reloaded.selectedLanguageID == 7)
        #expect(reloaded.pronunciationSystemID == "western")
        #expect(reloaded.appearanceRaw == "dark")
        #expect(reloaded.paletteID == "russian-flag")
        #expect(reloaded.cardFilterRaw == "capitals,lowercase")
        #expect(reloaded.isShuffled == true)
    }

    @Test func settingCustomPaletteDataRoundTrips() {
        let context = Self.makeContext()
        let store = UserPreferencesStore(context: context)
        let data = Data("custom-palette".utf8)

        store.setCustomPalette(data)
        #expect(store.customPaletteData == data)

        store.setCustomPalette(nil)
        #expect(store.customPaletteData == nil)
    }
}
