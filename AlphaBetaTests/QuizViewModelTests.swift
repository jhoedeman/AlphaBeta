import Testing
@testable import AlphaBeta

/// Always reports the same accuracy for every item — enough determinism for
/// `QuizViewModel` flow tests, which don't care about weighting itself
/// (that's covered in `QuizEngineTests`).
private struct FixedAccuracyProvider: ItemAccuracyProviding {
    func accuracy(for itemIdentifier: Int) -> Double? { nil }
}

/// Coverage for M6's `QuizViewModel`: filter-driven pool, submit/continue
/// state transitions, scoring, and the no-mutation-after-reveal guard.
struct QuizViewModelTests {
    private static let manifest = LanguageManifest(
        id: 1, code: "el", displayName: "Greek", nativeName: "Ελληνικά",
        scriptFamily: "Greek", fileName: "Greek", readingDirection: .leftToRight,
        hasLetterCase: true,
        pronunciationSystems: [PronunciationSystem(id: "modern", displayName: "Modern")],
        filterCategories: [.capitals, .lowercase, .diphthongs],
        defaultPaletteID: "greek-flag", flagEmoji: "🇬🇷"
    )

    private static func item(_ id: Int, _ letter: String) -> AlphabetItem {
        AlphabetItem(
            identifier: id, itemType: .letter, englishName: "Letter\(id)", foreignLetter: letter,
            exampleWord: nil, isVowel: nil, pronunciations: [:], languageSubtype: nil,
            foreignLetterName: nil, markedVersion: nil, markedCaseEquivalent: nil,
            caseEquivalent: nil, leadingCaseEquivalent: nil, middleCaseEquivalent: nil,
            endingCaseEquivalent: nil, lowercaseEnglishName: nil, explanation: nil
        )
    }

    private static let items = (1...15).map { item($0, "L\($0)") }

    private func makeViewModel() -> QuizViewModel {
        QuizViewModel(manifest: Self.manifest, allItems: Self.items, accuracyProvider: FixedAccuracyProvider())
    }

    @Test func defaultsToAllFiltersAndNoQuizYet() {
        let viewModel = makeViewModel()
        #expect(viewModel.selectedFilters == Set(Self.manifest.filterCategories))
        #expect(viewModel.questions.isEmpty)
        #expect(viewModel.pool.count == Self.items.count)
    }

    @Test func startQuizGeneratesTenQuestionsAndResetsState() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 1)
        viewModel.startQuiz(rng: &rng)
        #expect(viewModel.questions.count == 10)
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.score == 0)
        #expect(!viewModel.isFinished)
        #expect(viewModel.selectedOptionID == nil)
        #expect(!viewModel.isAnswerRevealed)
    }

    @Test func selectingAnOptionEnablesSubmit() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 2)
        viewModel.startQuiz(rng: &rng)
        #expect(!viewModel.canSubmit)

        let firstOption = viewModel.currentQuestion!.options.first!
        viewModel.selectOption(firstOption.id)
        #expect(viewModel.canSubmit)
    }

    @Test func submitRevealsAnswerAndLocksSelection() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 3)
        viewModel.startQuiz(rng: &rng)

        let wrongOption = viewModel.currentQuestion!.options.first { !$0.isCorrect }!
        viewModel.selectOption(wrongOption.id)
        viewModel.submit()

        #expect(viewModel.isAnswerRevealed)
        #expect(viewModel.score == 0)

        // Selecting a different option after reveal must not change anything.
        let correctOption = viewModel.currentQuestion!.options.first { $0.isCorrect }!
        viewModel.selectOption(correctOption.id)
        #expect(viewModel.selectedOptionID == wrongOption.id)
    }

    @Test func submitOnCorrectAnswerIncrementsScore() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 4)
        viewModel.startQuiz(rng: &rng)

        let correctOption = viewModel.currentQuestion!.options.first { $0.isCorrect }!
        viewModel.selectOption(correctOption.id)
        viewModel.submit()

        #expect(viewModel.score == 1)
    }

    @Test func continueBeforeSubmitIsANoOp() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 6)
        viewModel.startQuiz(rng: &rng)
        viewModel.continueToNext()
        #expect(viewModel.currentIndex == 0)
    }

    @Test func continueAdvancesToNextQuestionAndResetsSelection() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 5)
        viewModel.startQuiz(rng: &rng)

        let option = viewModel.currentQuestion!.options.first!
        viewModel.selectOption(option.id)
        viewModel.submit()
        viewModel.continueToNext()

        #expect(viewModel.currentIndex == 1)
        #expect(viewModel.selectedOptionID == nil)
        #expect(!viewModel.isAnswerRevealed)
    }

    @Test func continuingPastTheLastQuestionFinishesTheQuiz() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 8)
        viewModel.startQuiz(rng: &rng)

        for _ in 0..<viewModel.questions.count {
            let option = viewModel.currentQuestion!.options.first!
            viewModel.selectOption(option.id)
            viewModel.submit()
            viewModel.continueToNext()
        }

        #expect(viewModel.isFinished)
        #expect(viewModel.score >= 0 && viewModel.score <= 10)
    }

    @Test func returnToHomeClearsQuestionsAndFinishedState() {
        let viewModel = makeViewModel()
        var rng = SeededGenerator(seed: 9)
        viewModel.startQuiz(rng: &rng)
        viewModel.returnToHome()
        #expect(viewModel.questions.isEmpty)
        #expect(!viewModel.isFinished)
    }

    @Test func togglingAllFiltersOffEmptiesThePool() {
        let viewModel = makeViewModel()
        for category in Self.manifest.filterCategories {
            viewModel.toggleFilter(category)
        }
        #expect(viewModel.pool.isEmpty)
    }
}
