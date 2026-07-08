import Foundation

/// A single alphabet entry: a letter, diphthong, or letter combination.
/// Immutable content loaded from bundled JSON — never persisted to SwiftData.
/// User progress joins on `identifier`, never on an object reference, so
/// content can be freely revised without migrating user data.
struct AlphabetItem: Codable, Identifiable, Hashable, Sendable {
    let identifier: Int
    let itemType: ItemType
    let englishName: String
    let foreignLetter: String
    let exampleWord: String?
    let isVowel: Bool?
    let pronunciations: [String: PronunciationEntry]
    let languageSubtype: Int?
    let foreignLetterName: String?
    let markedVersion: String?
    let markedCaseEquivalent: String?
    let caseEquivalent: String?
    let leadingCaseEquivalent: String?
    let middleCaseEquivalent: String?
    let endingCaseEquivalent: String?
    let lowercaseEnglishName: String?
    let explanation: String?

    var id: Int { identifier }
}

extension AlphabetItem {
    /// True for the uppercase half of a case pair. Scripts with genuine
    /// Unicode case (Greek, Cyrillic, Armenian) resolve this correctly via
    /// `Character.isUppercase`; caseless scripts (Georgian Mkhedruli) always
    /// return false, matching their manifest's `hasLetterCase: false`.
    var isCapital: Bool {
        guard itemType == .letter, let first = foreignLetter.first else { return false }
        return first.isUppercase
    }

    /// The filter pill this item belongs to. `hasLetterCase` comes from the
    /// owning language's manifest since an item alone can't tell a caseless
    /// letter from a lowercase one.
    func category(hasLetterCase: Bool) -> FilterCategory {
        switch itemType {
        case .diphthong: .diphthongs
        case .combination: .combinations
        case .letter, .unknown:
            hasLetterCase ? (isCapital ? .capitals : .lowercase) : .letters
        }
    }

    /// Resolves this item's case-form references (`caseEquivalent`,
    /// `endingCaseEquivalent`, etc.) to their actual `AlphabetItem`s by
    /// matching `foreignLetter` within the same alphabet.
    func caseSiblings(in items: [AlphabetItem]) -> [AlphabetItem] {
        let glyphs = [caseEquivalent, leadingCaseEquivalent, middleCaseEquivalent, endingCaseEquivalent]
            .compactMap { $0 }
        guard !glyphs.isEmpty else { return [] }
        var seen = Set<Int>()
        return items.filter { sibling in
            guard glyphs.contains(sibling.foreignLetter), sibling.identifier != identifier else { return false }
            return seen.insert(sibling.identifier).inserted
        }
    }

    /// Same resolution as `caseSiblings(in:)`, but paired with a label
    /// naming the sibling's role — "Capital"/"Lowercase" for the plain case
    /// pair, or the specific positional form ("Ending form" for sigma
    /// teliko) — so the detail sheet never shows a bare, unlabeled glyph.
    func caseSiblingsWithRole(in items: [AlphabetItem]) -> [(item: AlphabetItem, role: String)] {
        let mapping: [(String?, (AlphabetItem) -> String)] = [
            (caseEquivalent, { $0.isCapital ? "Capital" : "Lowercase" }),
            (leadingCaseEquivalent, { _ in "Leading form" }),
            (middleCaseEquivalent, { _ in "Middle form" }),
            (endingCaseEquivalent, { _ in "Ending form" })
        ]
        var seen = Set<Int>()
        var results: [(item: AlphabetItem, role: String)] = []
        for (glyph, role) in mapping {
            guard let glyph,
                  let match = items.first(where: { $0.foreignLetter == glyph && $0.identifier != identifier }),
                  seen.insert(match.identifier).inserted else { continue }
            results.append((match, role(match)))
        }
        return results
    }

    /// Splits `exampleWord` strings of the form "Άλογο, which means 'horse'"
    /// into the native word and its English gloss. Strings that don't match
    /// the pattern fall back to showing the raw text as the word.
    var parsedExampleWord: (word: String, meaning: String?)? {
        guard let exampleWord else { return nil }
        guard let separatorRange = exampleWord.range(of: ", which means ") else {
            return (exampleWord, nil)
        }
        let word = String(exampleWord[..<separatorRange.lowerBound])
        let meaning = String(exampleWord[separatorRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        return (word, meaning)
    }

    /// Resolves the pronunciation entry to display, per SPEC §3.2: the
    /// requested system, else any system with data. Never returns an
    /// entry whose fields are all nil.
    func pronunciation(preferring systemID: String) -> PronunciationEntry? {
        func isPopulated(_ entry: PronunciationEntry) -> Bool {
            entry.full != nil || entry.short != nil || entry.letterName != nil
        }
        if let entry = pronunciations[systemID], isPopulated(entry) {
            return entry
        }
        return pronunciations.values.first(where: isPopulated)
    }
}
