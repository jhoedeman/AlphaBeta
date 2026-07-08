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
    private let accuracyProvider: ItemAccuracyProviding

    private(set) var selectedFilters: Set<FilterCategory>
    private(set) var questions: [QuizQuestion] = []
    private(set) var currentIndex = 0
    private(set) var selectedOptionID: UUID?
    private(set) var isAnswerRevealed = false
    private(set) var score = 0
    private(set) var isFinished = false

    init(manifest: LanguageManifest, allItems: [AlphabetItem], accuracyProvider: ItemAccuracyProviding = NoOpAccuracyProvider()) {
        self.manifest = manifest
        self.allItems = allItems
        self.accuracyProvider = accuracyProvider
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
            pronunciationSystemID: manifest.defaultPronunciationSystemID,
            accuracyProvider: accuracyProvider, rng: &rng
        )
        currentIndex = 0
        score = 0
        isFinished = false
        selectedOptionID = nil
        isAnswerRevealed = false
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
        if isCorrect {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    /// Advances past a revealed answer, or marks the quiz finished on the
    /// last question. Per SPEC §7.4, saving the session and showing results
    /// lands in M7 — for now `isFinished` just exposes the final score.
    func continueToNext() {
        guard isAnswerRevealed else { return }
        if isLastQuestion {
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
