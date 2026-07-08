import Foundation

/// Always reports "unseen" — a stand-in until M8 wires up the real
/// SwiftData `ItemProgress` accuracy lookup. Every item gets the unseen
/// weight (2.5) from `QuizEngine.weight(accuracy:)`.
struct NoOpAccuracyProvider: ItemAccuracyProviding {
    func accuracy(for itemIdentifier: Int) -> Double? { nil }
}

/// Drives the Quiz tab's filter → generate → answer → advance flow, per
/// SPEC §7.1/§7.3. Kept free of SwiftUI so submit/continue/scoring logic is
/// unit-testable independent of the swipe animation.
@Observable
final class QuizViewModel {
    let manifest: LanguageManifest
    let allItems: [AlphabetItem]
    let streakStore: StreakStore
    private let accuracyProvider: ItemAccuracyProviding
    private let userData: UserDataPersisting
    private let pronunciationSystemID: String

    private(set) var selectedFilters: Set<FilterCategory>
    private(set) var questions: [QuizQuestion] = []
    private(set) var answers: [QuizAnswerRecord] = []
    private(set) var currentIndex = 0
    private(set) var selectedOptionID: UUID?
    private(set) var isAnswerRevealed = false
    private(set) var score = 0
    private(set) var isFinished = false
    private(set) var streakJustEarnedToday = false
    private var quizStartedAt = Date.now

    init(
        manifest: LanguageManifest, allItems: [AlphabetItem], streakStore: StreakStore,
        accuracyProvider: ItemAccuracyProviding = NoOpAccuracyProvider(),
        userData: UserDataPersisting = NoOpUserDataPersisting(),
        pronunciationSystemID: String? = nil
    ) {
        self.manifest = manifest
        self.allItems = allItems
        self.streakStore = streakStore
        self.accuracyProvider = accuracyProvider
        self.userData = userData
        self.pronunciationSystemID = manifest.resolvedPronunciationSystemID(preferring: pronunciationSystemID ?? manifest.defaultPronunciationSystemID)
        selectedFilters = Set(manifest.filterCategories)
    }

    var pool: [AlphabetItem] {
        allItems.filter { selectedFilters.contains($0.category(hasLetterCase: manifest.hasLetterCase)) }
    }

    var currentQuestion: QuizQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var isLastQuestion: Bool { currentIndex == questions.count - 1 }
    var canSubmit: Bool { selectedOptionID != nil && !isAnswerRevealed }

    /// Looks up the subject item behind a question — needed by `.glyphToName`
    /// questions, which show the item's glyph as the prompt's visual subject.
    func subjectItem(for question: QuizQuestion) -> AlphabetItem? {
        allItems.first { $0.identifier == question.correctItemIdentifier }
    }

    func toggleFilter(_ category: FilterCategory) {
        if selectedFilters.contains(category) {
            selectedFilters.remove(category)
        } else {
            selectedFilters.insert(category)
        }
    }

    func startQuiz<G: RandomNumberGenerator>(rng: inout G) {
        questions = QuizEngine.generateQuiz(
            pool: pool, fullAlphabet: allItems, manifest: manifest,
            pronunciationSystemID: pronunciationSystemID,
            accuracyProvider: accuracyProvider, rng: &rng
        )
        currentIndex = 0
        score = 0
        isFinished = false
        streakJustEarnedToday = false
        answers = []
        selectedOptionID = nil
        isAnswerRevealed = false
        quizStartedAt = .now
    }

    func startQuiz() {
        var rng = SystemRandomNumberGenerator()
        startQuiz(rng: &rng)
    }

    func selectOption(_ id: UUID) {
        guard !isAnswerRevealed else { return }
        selectedOptionID = id
    }

    /// Locks in the current selection and reveals right/wrong. Idempotent
    /// once revealed — a second call (e.g. a stray tap) is a no-op.
    func submit() {
        guard !isAnswerRevealed, let question = currentQuestion, let selectedOptionID else { return }
        isAnswerRevealed = true
        let isCorrect = question.options.first { $0.id == selectedOptionID }?.isCorrect ?? false
        answers.append(QuizAnswerRecord(question: question, isCorrect: isCorrect))
        userData.recordAnswer(languageID: manifest.id, itemIdentifier: question.correctItemIdentifier, isCorrect: isCorrect)
        if isCorrect {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    /// Advances past a revealed answer, or on the last question records the
    /// completed session's streak credit and marks the quiz finished so the
    /// results sheet (SPEC §7.4) can present it.
    func continueToNext(now: Date = .now, calendar: Calendar = .current) {
        guard isAnswerRevealed else { return }
        if isLastQuestion {
            let today = calendar.startOfDay(for: now)
            let alreadyCreditedToday = streakStore.lastCompletedDay.map { calendar.startOfDay(for: $0) == today } ?? false
            streakStore.recordCompletion(now: now, calendar: calendar)
            streakJustEarnedToday = !alreadyCreditedToday
            userData.persistStreak(
                currentStreak: streakStore.currentStreak, longestStreak: streakStore.longestStreak,
                lastCompletedDay: today
            )
            userData.recordQuizSession(
                languageID: manifest.id, startedAt: quizStartedAt, completedAt: now,
                score: score, questionCount: questions.count,
                filtersUsedRaw: selectedFilters.map(\.rawValue).sorted().joined(separator: ",")
            )
            isFinished = true
        } else {
            currentIndex += 1
            selectedOptionID = nil
            isAnswerRevealed = false
        }
    }

    /// Resets to the pre-quiz filter screen without regenerating a quiz.
    func returnToHome() {
        questions = []
        isFinished = false
    }
}
