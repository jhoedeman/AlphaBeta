import Testing
@testable import AlphaBeta

/// Coverage for M4's detail-sheet helpers on `AlphabetItem`: example-word
/// parsing, pronunciation-system fallback, and role-labeled case siblings.
struct AlphabetItemDetailTests {
    private static func item(
        _ id: Int, _ letter: String, type: ItemType = .letter,
        exampleWord: String? = nil, pronunciations: [String: PronunciationEntry] = [:],
        caseEquivalent: String? = nil, endingCaseEquivalent: String? = nil
    ) -> AlphabetItem {
        AlphabetItem(
            identifier: id, itemType: type, englishName: "Letter \(id)", foreignLetter: letter,
            exampleWord: exampleWord, isVowel: nil, pronunciations: pronunciations, languageSubtype: nil,
            foreignLetterName: nil, markedVersion: nil, markedCaseEquivalent: nil,
            caseEquivalent: caseEquivalent, leadingCaseEquivalent: nil, middleCaseEquivalent: nil,
            endingCaseEquivalent: endingCaseEquivalent, lowercaseEnglishName: nil, explanation: nil
        )
    }

    @Test func parsedExampleWordSplitsWordAndMeaning() {
        let item = Self.item(1, "Α", exampleWord: "Άλογο, which means 'horse'")
        let parsed = item.parsedExampleWord
        #expect(parsed?.word == "Άλογο")
        #expect(parsed?.meaning == "horse")
    }

    @Test func parsedExampleWordFallsBackToRawStringWhenUnmatched() {
        let item = Self.item(1, "Α", exampleWord: "just a word")
        let parsed = item.parsedExampleWord
        #expect(parsed?.word == "just a word")
        #expect(parsed?.meaning == nil)
    }

    @Test func parsedExampleWordIsNilWhenAbsent() {
        let item = Self.item(1, "Α")
        #expect(item.parsedExampleWord == nil)
    }

    @Test func pronunciationPrefersRequestedSystem() {
        let item = Self.item(1, "Α", pronunciations: [
            "modern": PronunciationEntry(full: "modern full", short: nil, letterName: nil),
            "koine": PronunciationEntry(full: "koine full", short: nil, letterName: nil)
        ])
        #expect(item.pronunciation(preferring: "koine")?.full == "koine full")
    }

    @Test func pronunciationFallsBackToAnyPopulatedSystem() {
        let item = Self.item(1, "Α", pronunciations: [
            "modern": PronunciationEntry(full: "modern full", short: nil, letterName: nil)
        ])
        #expect(item.pronunciation(preferring: "koine")?.full == "modern full")
    }

    @Test func pronunciationIgnoresEmptyEntryForRequestedSystem() {
        let item = Self.item(1, "Α", pronunciations: [
            "modern": PronunciationEntry(full: nil, short: nil, letterName: nil),
            "koine": PronunciationEntry(full: "koine full", short: nil, letterName: nil)
        ])
        #expect(item.pronunciation(preferring: "modern")?.full == "koine full")
    }

    @Test func pronunciationIsNilWhenNoSystemHasData() {
        let item = Self.item(1, "Α")
        #expect(item.pronunciation(preferring: "modern") == nil)
    }

    @Test func caseSiblingsWithRoleLabelsEndingFormSeparately() {
        let capitalSigma = Self.item(1, "Σ", caseEquivalent: "σ", endingCaseEquivalent: "ς")
        let lowerSigma = Self.item(2, "σ")
        let endingSigma = Self.item(3, "ς")
        let allItems = [capitalSigma, lowerSigma, endingSigma]

        let siblings = capitalSigma.caseSiblingsWithRole(in: allItems)
        #expect(siblings.map(\.item.id) == [2, 3])
        #expect(siblings.map(\.role) == ["Case form", "Ending form"])
    }

    @Test func caseSiblingsWithRoleIsEmptyWhenNoEquivalents() {
        let item = Self.item(1, "Α")
        #expect(item.caseSiblingsWithRole(in: [item]).isEmpty)
    }
}
