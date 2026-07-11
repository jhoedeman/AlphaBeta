import Testing
import Foundation
@testable import AlphaBeta

/// Round-trip decode coverage for every bundled dataset, per SPEC §3.1/§10.
/// These run against the test bundle's copy of Content/Resources (added as
/// resources on the AlphaBetaTests target via xcodegen's shared `sources`
/// resolution — see project.yml).
struct ContentDecodingTests {
    static let expectedItemCounts: [String: Int] = [
        "Greek": 62,
        "Russian": 66,
        "Ukrainian": 66,
        "Belarusian": 64,
        "Serbian": 60,
        "Bulgarian": 60,
        "Macedonian": 62,
        "Armenian": 78,
        "Georgian": 33,
        "Coptic": 62,
    ]

    // Tests run hosted inside AlphaBeta.app (AlphaBetaTests.xctest lives in
    // its PlugIns), so `Bundle.main` here is the app bundle carrying the
    // Content/Resources JSON — not the xctest bundle itself.
    private func decodeFile(_ name: String) throws -> AlphabetFile {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AlphabetFile.self, from: data)
    }

    @Test func manifestDecodesAllTenLanguages() throws {
        let registry = try LanguageRegistry()
        #expect(registry.languages.count == 10)
    }

    @Test func everyManifestFileNameHasAMatchingBundledJSON() throws {
        let registry = try LanguageRegistry()
        for language in registry.languages {
            let file = try decodeFile(language.fileName)
            let alphabet = try #require(file.alphabets.first { $0.language == language.id })
            #expect(alphabet.alphabetItems.isEmpty == false)
        }
    }

    @Test func everyManifestDefaultPaletteResolves() throws {
        let registry = try LanguageRegistry()
        let palettes = try PaletteRegistry()
        for language in registry.languages {
            #expect(palettes.palette(forID: language.defaultPaletteID) != nil,
                     "no palette for \(language.defaultPaletteID)")
        }
    }

    @Test(arguments: Array(expectedItemCounts.keys))
    func datasetHasExpectedItemCount(fileName: String) throws {
        let file = try decodeFile(fileName)
        let expected = try #require(Self.expectedItemCounts[fileName])
        let actual = file.alphabets.reduce(0) { $0 + $1.alphabetItems.count }
        #expect(actual == expected)
    }

    @Test func greekSigmaFamilyResolvesCaseSiblings() throws {
        let file = try decodeFile("Greek")
        let items = try #require(file.alphabets.first).alphabetItems
        let capitalSigma = try #require(items.first { $0.foreignLetter == "Σ" })
        #expect(capitalSigma.caseEquivalent == "σ")
        #expect(capitalSigma.endingCaseEquivalent == "ς")

        let siblings = capitalSigma.caseSiblings(in: items)
        let glyphs = Set(siblings.map(\.foreignLetter))
        #expect(glyphs == ["σ", "ς"])

        // Final sigma points back to both leading/middle sigma and capital sigma.
        let finalSigma = try #require(items.first { $0.foreignLetter == "ς" })
        #expect(finalSigma.leadingCaseEquivalent == "σ")
        #expect(finalSigma.middleCaseEquivalent == "σ")
        #expect(finalSigma.caseEquivalent == "Σ")
    }

    @Test func russianSignsAndYeryHaveNoCaseEquivalentButDoHaveCapitals() throws {
        let file = try decodeFile("Russian")
        let items = try #require(file.alphabets.first).alphabetItems
        for glyph in ["ъ", "ь", "ы"] {
            let lower = try #require(items.first { $0.foreignLetter == glyph })
            #expect(lower.isVowel == (glyph == "ы"))
            #expect(lower.caseEquivalent != nil, "\(glyph) should still declare its capital form")
        }
    }

    @Test func armenianItemsCarryBothPronunciationSystems() throws {
        let file = try decodeFile("Armenian")
        let items = try #require(file.alphabets.first).alphabetItems
        let letters = items.filter { $0.itemType == .letter }
        #expect(letters.isEmpty == false)
        for letter in letters where letter.foreignLetterName != nil {
            #expect(letter.pronunciations["eastern"] != nil || letter.pronunciations["western"] != nil,
                     "\(letter.englishName) missing both eastern/western systems")
        }
    }

    @Test func armenianHasOneDiphthongAndOneCombination() throws {
        let file = try decodeFile("Armenian")
        let items = try #require(file.alphabets.first).alphabetItems
        #expect(items.filter { $0.itemType == .diphthong }.count == 1)
        #expect(items.filter { $0.itemType == .combination }.count == 1)
    }

    @Test func georgianItemsAreCaselessWithNoEquivalentFields() throws {
        let registry = try LanguageRegistry()
        let georgian = try #require(registry.manifest(forID: 8))
        #expect(georgian.hasLetterCase == false)
        #expect(georgian.filterCategories == [.letters])

        let file = try decodeFile("Georgian")
        let items = try #require(file.alphabets.first).alphabetItems
        for item in items {
            #expect(item.caseEquivalent == nil)
            #expect(item.isCapital == false)
            #expect(item.category(hasLetterCase: georgian.hasLetterCase) == .letters)
        }
    }

    @Test func copticHasLetterCaseAndOneBohairicPronunciationSystem() throws {
        let registry = try LanguageRegistry()
        let coptic = try #require(registry.manifest(forID: 9))
        #expect(coptic.hasLetterCase)
        #expect(coptic.filterCategories == [.capitals, .lowercase])
        #expect(coptic.pronunciationSystems.map(\.id) == ["bohairic"])

        let file = try decodeFile("Coptic")
        let items = try #require(file.alphabets.first).alphabetItems
        let capitalAlfa = try #require(items.first { $0.foreignLetter == "Ⲁ" })
        #expect(capitalAlfa.caseEquivalent == "ⲁ")
        #expect(capitalAlfa.isCapital)
        #expect(capitalAlfa.pronunciation(preferring: "bohairic")?.short != nil)

        let lowerAlfa = try #require(items.first { $0.foreignLetter == "ⲁ" })
        #expect(lowerAlfa.caseEquivalent == "Ⲁ")
        #expect(lowerAlfa.isCapital == false)
    }

    @Test func unknownItemTypeDecodesWithoutThrowing() throws {
        let json = """
        {"identifier": 9999, "itemType": 42, "englishName": "Future", "foreignLetter": "X",
         "pronunciations": {}}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(AlphabetItem.self, from: json)
        #expect(item.itemType == .unknown)
    }
}
