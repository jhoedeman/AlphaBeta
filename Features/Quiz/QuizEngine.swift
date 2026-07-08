import Foundation

/// Pure, stateless quiz generator (SPEC §7.2). Takes the filtered item pool
/// plus the full alphabet as a distractor fallback so a quiz can never be
/// blocked by a too-small filter selection, and an `ItemAccuracyProviding`
/// so item-selection frequency adapts to how the user is doing without the
/// engine knowing anything about SwiftData.
enum QuizEngine {
    static let questionCount = 10

    static func generateQuiz<G: RandomNumberGenerator>(
        pool: [AlphabetItem],
        fullAlphabet: [AlphabetItem],
        manifest: LanguageManifest,
        pronunciationSystemID: String,
        accuracyProvider: ItemAccuracyProviding,
        rng: inout G
    ) -> [QuizQuestion] {
        guard !pool.isEmpty else { return [] }

        let subjects = weightedSample(
            from: pool,
            count: questionCount,
            allowRepeats: pool.count < questionCount,
            accuracyProvider: accuracyProvider,
            rng: &rng
        )

        return subjects.compactMap { subject in
            let types = validTypes(for: subject, manifest: manifest, pronunciationSystemID: pronunciationSystemID)
                .shuffled(using: &rng)
            for type in types {
                if let question = generateQuestion(
                    for: subject, type: type, pool: pool, fullAlphabet: fullAlphabet,
                    manifest: manifest, pronunciationSystemID: pronunciationSystemID, rng: &rng
                ) {
                    return question
                }
            }
            return nil
        }
    }

    /// SPEC §7.2 weighting: `1 + 3 × (1 − accuracy)`, unseen items at 2.5,
    /// clamped to [1, 4].
    static func weight(accuracy: Double?) -> Double {
        guard let accuracy else { return 2.5 }
        return min(4, max(1, 1 + 3 * (1 - accuracy)))
    }

    /// Weighted sampling. Without replacement while the pool can still cover
    /// `count` distinct items; with replacement once it can't, so a quiz
    /// always has exactly `count` questions even from a tiny filtered pool.
    static func weightedSample<G: RandomNumberGenerator>(
        from pool: [AlphabetItem],
        count: Int,
        allowRepeats: Bool,
        accuracyProvider: ItemAccuracyProviding,
        rng: inout G
    ) -> [AlphabetItem] {
        guard !pool.isEmpty else { return [] }
        if allowRepeats {
            return (0..<count).map { _ in weightedPick(from: pool, accuracyProvider: accuracyProvider, rng: &rng) }
        }
        var remaining = pool
        var results: [AlphabetItem] = []
        for _ in 0..<min(count, pool.count) {
            let picked = weightedPick(from: remaining, accuracyProvider: accuracyProvider, rng: &rng)
            results.append(picked)
            remaining.removeAll { $0.identifier == picked.identifier }
        }
        return results
    }

    private static func weightedPick<G: RandomNumberGenerator>(
        from items: [AlphabetItem], accuracyProvider: ItemAccuracyProviding, rng: inout G
    ) -> AlphabetItem {
        let weights = items.map { weight(accuracy: accuracyProvider.accuracy(for: $0.identifier)) }
        let total = weights.reduce(0, +)
        var threshold = Double.random(in: 0..<total, using: &rng)
        for (item, itemWeight) in zip(items, weights) {
            if threshold < itemWeight { return item }
            threshold -= itemWeight
        }
        return items[items.count - 1]
    }

    static func validTypes(
        for item: AlphabetItem, manifest: LanguageManifest, pronunciationSystemID: String
    ) -> [QuestionType] {
        var types: [QuestionType] = [.glyphToName, .nameToGlyph]
        if item.parsedExampleWord != nil {
            types.append(.wordContains)
            types.append(.nameToWord)
        }
        if manifest.hasLetterCase, item.caseEquivalent != nil {
            types.append(.caseMatch)
        }
        if item.pronunciation(preferring: pronunciationSystemID)?.short != nil {
            types.append(.soundToGlyph)
        }
        return types
    }

    static func generateQuestion<G: RandomNumberGenerator>(
        for item: AlphabetItem, type: QuestionType, pool: [AlphabetItem], fullAlphabet: [AlphabetItem],
        manifest: LanguageManifest, pronunciationSystemID: String, rng: inout G
    ) -> QuizQuestion? {
        switch type {
        case .glyphToName:
            return glyphToName(item, pool: pool, fullAlphabet: fullAlphabet, manifest: manifest, rng: &rng)
        case .nameToGlyph:
            return nameToGlyph(item, pool: pool, fullAlphabet: fullAlphabet, manifest: manifest, rng: &rng)
        case .wordContains:
            return wordContains(item, pool: pool, fullAlphabet: fullAlphabet, manifest: manifest, rng: &rng)
        case .nameToWord:
            return nameToWord(item, pool: pool, fullAlphabet: fullAlphabet, manifest: manifest, rng: &rng)
        case .caseMatch:
            return caseMatch(item, pool: pool, fullAlphabet: fullAlphabet, rng: &rng)
        case .soundToGlyph:
            return soundToGlyph(item, pool: pool, fullAlphabet: fullAlphabet, manifest: manifest, pronunciationSystemID: pronunciationSystemID, rng: &rng)
        }
    }

    // MARK: - Question builders

    static func glyphToName<G: RandomNumberGenerator>(
        _ item: AlphabetItem, pool: [AlphabetItem], fullAlphabet: [AlphabetItem], manifest: LanguageManifest, rng: inout G
    ) -> QuizQuestion? {
        let distractors = pickDistractors(
            count: 3, excluding: item, from: [pool, fullAlphabet],
            isValid: { sameCategory($0, item, manifest: manifest) }, rng: &rng
        )
        guard distractors.count == 3 else { return nil }
        let options = ([item] + distractors).map { QuizOption(text: $0.englishName, itemIdentifier: $0.identifier, isCorrect: $0.identifier == item.identifier) }
        return QuizQuestion(
            type: .glyphToName, prompt: "What is this called?",
            correctItemIdentifier: item.identifier, options: options.shuffled(using: &rng)
        )
    }

    static func nameToGlyph<G: RandomNumberGenerator>(
        _ item: AlphabetItem, pool: [AlphabetItem], fullAlphabet: [AlphabetItem], manifest: LanguageManifest, rng: inout G
    ) -> QuizQuestion? {
        let distractors = pickDistractors(
            count: 3, excluding: item, from: [pool, fullAlphabet],
            isValid: { sameCategory($0, item, manifest: manifest) }, rng: &rng
        )
        guard distractors.count == 3 else { return nil }
        let options = ([item] + distractors).map { QuizOption(text: $0.foreignLetter, itemIdentifier: $0.identifier, isCorrect: $0.identifier == item.identifier) }
        return QuizQuestion(
            type: .nameToGlyph, prompt: "Which one is \(item.englishName)?",
            correctItemIdentifier: item.identifier, options: options.shuffled(using: &rng)
        )
    }

    static func wordContains<G: RandomNumberGenerator>(
        _ item: AlphabetItem, pool: [AlphabetItem], fullAlphabet: [AlphabetItem], manifest: LanguageManifest, rng: inout G
    ) -> QuizQuestion? {
        guard let parsed = item.parsedExampleWord, contains(word: parsed.word, glyph: item.foreignLetter) else { return nil }
        let distractors = pickDistractors(
            count: 3, excluding: item, from: [pool, fullAlphabet],
            isValid: { sameCategory($0, item, manifest: manifest) && !contains(word: parsed.word, glyph: $0.foreignLetter) },
            rng: &rng
        )
        guard distractors.count == 3 else { return nil }
        let options = ([item] + distractors).map { QuizOption(text: $0.englishName, itemIdentifier: $0.identifier, isCorrect: $0.identifier == item.identifier) }
        return QuizQuestion(
            type: .wordContains, prompt: "Which letter appears in \"\(parsed.word)\"?",
            correctItemIdentifier: item.identifier, options: options.shuffled(using: &rng)
        )
    }

    static func nameToWord<G: RandomNumberGenerator>(
        _ item: AlphabetItem, pool: [AlphabetItem], fullAlphabet: [AlphabetItem], manifest: LanguageManifest, rng: inout G
    ) -> QuizQuestion? {
        guard item.parsedExampleWord != nil else { return nil }
        let distractors = pickDistractors(
            count: 3, excluding: item, from: [pool, fullAlphabet],
            isValid: { candidate in
                guard sameCategory(candidate, item, manifest: manifest),
                      let candidateParsed = candidate.parsedExampleWord else { return false }
                return !contains(word: candidateParsed.word, glyph: item.foreignLetter)
            },
            rng: &rng
        )
        guard distractors.count == 3 else { return nil }
        let allItems = [item] + distractors
        let options = allItems.map { candidate -> QuizOption in
            let word = candidate.parsedExampleWord?.word ?? candidate.foreignLetter
            return QuizOption(text: word, itemIdentifier: candidate.identifier, isCorrect: candidate.identifier == item.identifier)
        }
        let name = item.lowercaseEnglishName ?? item.englishName.lowercased()
        return QuizQuestion(
            type: .nameToWord, prompt: "Which word contains \(indefiniteArticle(for: name)) \(name)?",
            correctItemIdentifier: item.identifier, options: options.shuffled(using: &rng)
        )
    }

    /// "a"/"an" for a letter name, by leading *sound* rather than spelling —
    /// "iota" starts with a consonant y-sound ("yo-ta"), so it's the one
    /// vowel-spelled exception that still takes "a".
    private static func indefiniteArticle(for word: String) -> String {
        let consonantSoundExceptions: Set<String> = ["iota"]
        guard !consonantSoundExceptions.contains(word.lowercased()) else { return "a" }
        guard let first = word.first?.lowercased() else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    static func caseMatch<G: RandomNumberGenerator>(
        _ item: AlphabetItem, pool: [AlphabetItem], fullAlphabet: [AlphabetItem], rng: inout G
    ) -> QuizQuestion? {
        guard let correctGlyph = item.caseEquivalent else { return nil }
        let distractors = pickDistractors(
            count: 3, excluding: item, from: [pool, fullAlphabet],
            isValid: { candidate in
                guard let candidateEquivalent = candidate.caseEquivalent,
                      candidate.isCapital == item.isCapital,
                      candidateEquivalent != correctGlyph else { return false }
                return true
            },
            rng: &rng
        )
        guard distractors.count == 3 else { return nil }
        let allItems = [item] + distractors
        let options = allItems.map { candidate -> QuizOption in
            let glyph = candidate.identifier == item.identifier ? correctGlyph : (candidate.caseEquivalent ?? candidate.foreignLetter)
            return QuizOption(text: glyph, itemIdentifier: candidate.identifier, isCorrect: candidate.identifier == item.identifier)
        }
        let targetCase = item.isCapital ? "lowercase" : "capital"
        return QuizQuestion(
            type: .caseMatch, prompt: "Which is the \(targetCase) form of \(item.foreignLetter)?",
            correctItemIdentifier: item.identifier, options: options.shuffled(using: &rng)
        )
    }

    static func soundToGlyph<G: RandomNumberGenerator>(
        _ item: AlphabetItem, pool: [AlphabetItem], fullAlphabet: [AlphabetItem], manifest: LanguageManifest,
        pronunciationSystemID: String, rng: inout G
    ) -> QuizQuestion? {
        guard let short = item.pronunciation(preferring: pronunciationSystemID)?.short else { return nil }
        let distractors = pickDistractors(
            count: 3, excluding: item, from: [pool, fullAlphabet],
            isValid: { candidate in
                guard sameCategory(candidate, item, manifest: manifest),
                      let candidateShort = candidate.pronunciation(preferring: pronunciationSystemID)?.short else { return false }
                return normalize(candidateShort) != normalize(short)
            },
            rng: &rng
        )
        guard distractors.count == 3 else { return nil }
        let options = ([item] + distractors).map { QuizOption(text: $0.foreignLetter, itemIdentifier: $0.identifier, isCorrect: $0.identifier == item.identifier) }
        return QuizQuestion(
            type: .soundToGlyph, prompt: "Which letter sounds like '\(short)'?",
            correctItemIdentifier: item.identifier, options: options.shuffled(using: &rng)
        )
    }

    // MARK: - Shared helpers

    /// Distractor fairness rule (SPEC §7.2): same `itemType`, and same case
    /// when the language has letter case.
    static func sameCategory(_ candidate: AlphabetItem, _ item: AlphabetItem, manifest: LanguageManifest) -> Bool {
        guard candidate.itemType == item.itemType else { return false }
        guard manifest.hasLetterCase, item.itemType == .letter else { return true }
        return candidate.isCapital == item.isCapital
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    static func contains(word: String, glyph: String) -> Bool {
        normalize(word).contains(normalize(glyph))
    }

    /// Pulls up to `count` distinct distractors from `candidatePools` in
    /// order — normally `[filteredPool, fullAlphabet]` — so a too-small
    /// filter selection never blocks question generation (SPEC §7.2).
    static func pickDistractors<G: RandomNumberGenerator>(
        count: Int, excluding item: AlphabetItem, from candidatePools: [[AlphabetItem]],
        isValid: (AlphabetItem) -> Bool, rng: inout G
    ) -> [AlphabetItem] {
        var seen: Set<Int> = [item.identifier]
        var results: [AlphabetItem] = []
        for candidatePool in candidatePools {
            guard results.count < count else { break }
            let eligible = candidatePool.filter { !seen.contains($0.identifier) && isValid($0) }
            for candidate in eligible.shuffled(using: &rng) {
                guard results.count < count else { break }
                results.append(candidate)
                seen.insert(candidate.identifier)
            }
        }
        return results
    }
}
