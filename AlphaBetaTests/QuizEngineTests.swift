import Testing
@testable import AlphaBeta

/// Deterministic xorshift generator so quiz generation tests are
/// reproducible without depending on the system RNG.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 0xBF58476D1CE4E5B9
        if state == 0 { state = 0x9E3779B97F4A7C15 }
        for _ in 0..<8 { _ = next() } // warm up so small seeds still mix well
    }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Fixed accuracy lookup for weighting tests.
struct StubAccuracyProvider: ItemAccuracyProviding {
    let accuracies: [Int: Double]
    func accuracy(for itemIdentifier: Int) -> Double? { accuracies[itemIdentifier] }
}

/// Coverage for M5's `QuizEngine`, per SPEC §7.2 and §10: distractor
/// validity for the substring/sound-collision rules, no-repeat subjects,
/// small-pool degradation, and weighting sanity.
struct QuizEngineTests {
    private static let manifest = LanguageManifest(
        id: 1, code: "el", displayName: "Greek", nativeName: "Ελληνικά",
        scriptFamily: "Greek", fileName: "Greek", readingDirection: .leftToRight,
        hasLetterCase: true,
        pronunciationSystems: [PronunciationSystem(id: "modern", displayName: "Modern")],
        filterCategories: [.capitals, .lowercase, .diphthongs],
        defaultPaletteID: "greek-flag", flagEmoji: "🇬🇷"
    )

    private static let caselessManifest = LanguageManifest(
        id: 8, code: "ka", displayName: "Georgian", nativeName: "ქართული",
        scriptFamily: "Georgian", fileName: "Georgian", readingDirection: .leftToRight,
        hasLetterCase: false,
        pronunciationSystems: [PronunciationSystem(id: "modern", displayName: "Modern")],
        filterCategories: [.letters],
        defaultPaletteID: "georgian", flagEmoji: "🇬🇪"
    )

    private static func item(
        _ id: Int, _ letter: String, name: String? = nil, type: ItemType = .letter,
        exampleWord: String? = nil, pronunciations: [String: PronunciationEntry] = [:],
        caseEquivalent: String? = nil, lowercaseEnglishName: String? = nil
    ) -> AlphabetItem {
        AlphabetItem(
            identifier: id, itemType: type, englishName: name ?? "Letter\(id)", foreignLetter: letter,
            exampleWord: exampleWord, isVowel: nil, pronunciations: pronunciations, languageSubtype: nil,
            foreignLetterName: nil, markedVersion: nil, markedCaseEquivalent: nil,
            caseEquivalent: caseEquivalent, leadingCaseEquivalent: nil, middleCaseEquivalent: nil,
            endingCaseEquivalent: nil, lowercaseEnglishName: lowercaseEnglishName, explanation: nil
        )
    }

    // MARK: - Weighting

    @Test func weightIsMaxForUnseenItems() {
        #expect(QuizEngine.weight(accuracy: nil) == 2.5)
    }

    @Test func weightClampsAtFourForZeroAccuracy() {
        #expect(QuizEngine.weight(accuracy: 0) == 4)
    }

    @Test func weightClampsAtOneForPerfectAccuracy() {
        #expect(QuizEngine.weight(accuracy: 1) == 1)
    }

    @Test func weightIsMidpointForHalfAccuracy() {
        #expect(QuizEngine.weight(accuracy: 0.5) == 2.5)
    }

    @Test func weightedSampleFavorsLowAccuracyItemsOverManyDraws() {
        let struggling = Self.item(1, "Α")
        let mastered = Self.item(2, "Β")
        let accuracy = StubAccuracyProvider(accuracies: [1: 0, 2: 1])

        var strugglingPicks = 0
        for seed in 1...200 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let picked = QuizEngine.weightedSample(
                from: [struggling, mastered], count: 1, allowRepeats: true,
                accuracyProvider: accuracy, rng: &rng
            )
            if picked.first?.identifier == 1 { strugglingPicks += 1 }
        }
        // Weight ratio is 4:1, so the struggling item should dominate but
        // the mastered item should still appear sometimes.
        #expect(strugglingPicks > 120)
        #expect(strugglingPicks < 200)
    }

    // MARK: - No-repeat / small-pool degradation

    @Test func generateQuizHasNoRepeatedSubjectWhenPoolIsLargeEnough() {
        let items = (1...12).map { Self.item($0, "L\($0)") }
        let accuracy = StubAccuracyProvider(accuracies: [:])
        var rng = SeededGenerator(seed: 42)
        let questions = QuizEngine.generateQuiz(
            pool: items, fullAlphabet: items, manifest: Self.manifest,
            pronunciationSystemID: "modern", accuracyProvider: accuracy, rng: &rng
        )
        #expect(questions.count == QuizEngine.questionCount)
        let subjects = questions.map(\.correctItemIdentifier)
        #expect(Set(subjects).count == subjects.count)
    }

    @Test func generateQuizDegradesToTenQuestionsWithRepeatsWhenPoolIsSmall() {
        // Filtered pool has only 3 items, but the full alphabet (used as
        // distractor fallback) is large enough to still build every question.
        let pool = (1...3).map { Self.item($0, "L\($0)") }
        let fullAlphabet = pool + (4...20).map { Self.item($0, "L\($0)") }
        let accuracy = StubAccuracyProvider(accuracies: [:])
        var rng = SeededGenerator(seed: 7)
        let questions = QuizEngine.generateQuiz(
            pool: pool, fullAlphabet: fullAlphabet, manifest: Self.manifest,
            pronunciationSystemID: "modern", accuracyProvider: accuracy, rng: &rng
        )
        #expect(questions.count == QuizEngine.questionCount)
    }

    @Test func generateQuizNeverBlocksWhenPoolIsSmallerThanFour() {
        // Only 2 items in the filtered pool — Q1/Q2 distractors must fall
        // back to the full alphabet rather than failing to generate.
        let pool = (1...2).map { Self.item($0, "L\($0)") }
        let fullAlphabet = pool + (3...8).map { Self.item($0, "L\($0)") }
        let accuracy = StubAccuracyProvider(accuracies: [:])
        var rng = SeededGenerator(seed: 3)
        let questions = QuizEngine.generateQuiz(
            pool: pool, fullAlphabet: fullAlphabet, manifest: Self.manifest,
            pronunciationSystemID: "modern", accuracyProvider: accuracy, rng: &rng
        )
        #expect(questions.count == QuizEngine.questionCount)
    }

    // MARK: - Q3/Q4 substring rule

    @Test func wordContainsQuestionExcludesDistractorsWhoseGlyphAlsoAppearsInWord() {
        // "Alpha" contains both Α and, say, a decoy sharing a letterform —
        // the decoy must never be offered as a correct-seeming distractor.
        let target = Self.item(1, "Α", exampleWord: "Άλφα, which means 'nothing'")
        let sneakyDistractor = Self.item(2, "λ") // λ also appears in "Άλφα"
        let safeDistractor1 = Self.item(3, "Β")
        let safeDistractor2 = Self.item(4, "Γ")
        let safeDistractor3 = Self.item(5, "Δ")
        let pool = [target, sneakyDistractor, safeDistractor1, safeDistractor2, safeDistractor3]

        var rng = SeededGenerator(seed: 99)
        guard let question = QuizEngine.wordContains(target, pool: pool, fullAlphabet: pool, manifest: Self.manifest, rng: &rng) else {
            Issue.record("expected a wordContains question to be generated")
            return
        }
        let distractorIDs = question.options.filter { !$0.isCorrect }.map(\.itemIdentifier)
        #expect(!distractorIDs.contains(sneakyDistractor.identifier))
        #expect(distractorIDs.count == 3)
    }

    @Test func nameToWordQuestionExcludesWordsThatAlsoContainTheTargetGlyph() {
        let target = Self.item(1, "Λ", exampleWord: "Λάμπα, which means 'lamp'")
        let sneakyDistractor = Self.item(2, "Μ", exampleWord: "Λεμόνι, which means 'lemon'") // also has Λ
        let safe1 = Self.item(3, "Ν", exampleWord: "Νερό, which means 'water'")
        let safe2 = Self.item(4, "Ξ", exampleWord: "Ξένος, which means 'stranger'")
        let safe3 = Self.item(5, "Ο", exampleWord: "Ουρανός, which means 'sky'")
        let pool = [target, sneakyDistractor, safe1, safe2, safe3]

        var rng = SeededGenerator(seed: 11)
        guard let question = QuizEngine.nameToWord(target, pool: pool, fullAlphabet: pool, manifest: Self.manifest, rng: &rng) else {
            Issue.record("expected a nameToWord question to be generated")
            return
        }
        let distractorIDs = question.options.filter { !$0.isCorrect }.map(\.itemIdentifier)
        #expect(!distractorIDs.contains(sneakyDistractor.identifier))
        #expect(distractorIDs.count == 3)
    }

    @Test func nameToWordUsesAnBeforeAVowelSoundingLetterName() {
        let target = Self.item(1, "Ε", exampleWord: "Επιτυχία, which means 'success'", lowercaseEnglishName: "epsilon")
        let pool = [target] + (2...5).map { Self.item($0, "L\($0)", exampleWord: "word\($0), which means 'thing'") }

        var rng = SeededGenerator(seed: 13)
        guard let question = QuizEngine.nameToWord(target, pool: pool, fullAlphabet: pool, manifest: Self.manifest, rng: &rng) else {
            Issue.record("expected a nameToWord question to be generated")
            return
        }
        #expect(question.prompt == "Which word contains an epsilon?")
    }

    @Test func nameToWordUsesABeforeIotaDespiteItsVowelSpelling() {
        // "Iota" is pronounced with a leading consonant y-sound ("yo-ta"),
        // so it's the one vowel-spelled exception that still takes "a".
        let target = Self.item(1, "Ι", exampleWord: "Ιστορία, which means 'story'", lowercaseEnglishName: "iota")
        let pool = [target] + (2...5).map { Self.item($0, "L\($0)", exampleWord: "word\($0), which means 'thing'") }

        var rng = SeededGenerator(seed: 17)
        guard let question = QuizEngine.nameToWord(target, pool: pool, fullAlphabet: pool, manifest: Self.manifest, rng: &rng) else {
            Issue.record("expected a nameToWord question to be generated")
            return
        }
        #expect(question.prompt == "Which word contains a iota?")
    }

    @Test func nameToWordUsesABeforeAConsonantSoundingLetterName() {
        let target = Self.item(1, "Λ", exampleWord: "Λάμπα, which means 'lamp'", lowercaseEnglishName: "lambda")
        let pool = [target] + (2...5).map { Self.item($0, "L\($0)", exampleWord: "word\($0), which means 'thing'") }

        var rng = SeededGenerator(seed: 19)
        guard let question = QuizEngine.nameToWord(target, pool: pool, fullAlphabet: pool, manifest: Self.manifest, rng: &rng) else {
            Issue.record("expected a nameToWord question to be generated")
            return
        }
        #expect(question.prompt == "Which word contains a lambda?")
    }

    // MARK: - Q6 sound-collision rule

    @Test func soundToGlyphQuestionExcludesDistractorsSharingTheSameSound() {
        // Greek trap: η/ι/υ all sound like "ee".
        let target = Self.item(1, "Η", pronunciations: ["modern": PronunciationEntry(full: nil, short: "ee", letterName: nil)])
        let collidingIota = Self.item(2, "Ι", pronunciations: ["modern": PronunciationEntry(full: nil, short: "ee", letterName: nil)])
        let collidingUpsilon = Self.item(3, "Υ", pronunciations: ["modern": PronunciationEntry(full: nil, short: "ee", letterName: nil)])
        let safe1 = Self.item(4, "Β", pronunciations: ["modern": PronunciationEntry(full: nil, short: "v", letterName: nil)])
        let safe2 = Self.item(5, "Γ", pronunciations: ["modern": PronunciationEntry(full: nil, short: "gh", letterName: nil)])
        let safe3 = Self.item(6, "Δ", pronunciations: ["modern": PronunciationEntry(full: nil, short: "th", letterName: nil)])
        let pool = [target, collidingIota, collidingUpsilon, safe1, safe2, safe3]

        var rng = SeededGenerator(seed: 5)
        guard let question = QuizEngine.soundToGlyph(target, pool: pool, fullAlphabet: pool, manifest: Self.manifest, pronunciationSystemID: "modern", rng: &rng) else {
            Issue.record("expected a soundToGlyph question to be generated")
            return
        }
        let distractorIDs = question.options.filter { !$0.isCorrect }.map(\.itemIdentifier)
        #expect(!distractorIDs.contains(collidingIota.identifier))
        #expect(!distractorIDs.contains(collidingUpsilon.identifier))
        #expect(distractorIDs.count == 3)
    }

    // MARK: - Q5 case match

    @Test func caseMatchOffersOnlyLowercaseDistractorsWhenAskingForLowercase() {
        let target = Self.item(1, "Σ", caseEquivalent: "σ")
        let otherCapital = Self.item(2, "Β", caseEquivalent: "β")
        let stray = Self.item(3, "γ", caseEquivalent: "Γ") // itself lowercase — wrong direction
        let safe1 = Self.item(4, "Δ", caseEquivalent: "δ")
        let safe2 = Self.item(5, "Ε", caseEquivalent: "ε")
        let pool = [target, otherCapital, stray, safe1, safe2]

        var rng = SeededGenerator(seed: 21)
        guard let question = QuizEngine.caseMatch(target, pool: pool, fullAlphabet: pool, rng: &rng) else {
            Issue.record("expected a caseMatch question to be generated")
            return
        }
        #expect(!question.options.filter { !$0.isCorrect }.map(\.itemIdentifier).contains(stray.identifier))
        #expect(question.options.first { $0.isCorrect }?.text == "σ")
    }

    @Test func caseMatchIsSkippedForCaselessLanguages() {
        let target = Self.item(1, "ა")
        let types = QuizEngine.validTypes(for: target, manifest: Self.caselessManifest, pronunciationSystemID: "modern")
        #expect(!types.contains(.caseMatch))
    }
}
