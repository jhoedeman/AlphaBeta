import Testing
@testable import AlphaBeta

/// M9: pronunciation-system preference resolution, per SPEC §9's Settings
/// picker — a stale preference from a previously-selected language must
/// fall back to the current language's default rather than crash or hide
/// pronunciation content.
struct LanguageManifestTests {
    private static let armenian = LanguageManifest(
        id: 7, code: "hy", displayName: "Armenian", nativeName: "Հայերեն",
        scriptFamily: "Armenian", fileName: "Armenian", readingDirection: .leftToRight,
        hasLetterCase: true,
        pronunciationSystems: [
            PronunciationSystem(id: "eastern", displayName: "Eastern"),
            PronunciationSystem(id: "western", displayName: "Western"),
        ],
        filterCategories: [.capitals, .lowercase],
        defaultPaletteID: "armenian-flag", flagEmoji: "🇦🇲"
    )

    private static let greek = LanguageManifest(
        id: 0, code: "el", displayName: "Greek", nativeName: "Ελληνικά",
        scriptFamily: "Greek", fileName: "Greek", readingDirection: .leftToRight,
        hasLetterCase: true,
        pronunciationSystems: [PronunciationSystem(id: "modern", displayName: "Modern")],
        filterCategories: [.capitals, .lowercase],
        defaultPaletteID: "greek-flag", flagEmoji: "🇬🇷"
    )

    @Test func preferenceThatExistsOnTheLanguageIsUsedAsIs() {
        #expect(Self.armenian.resolvedPronunciationSystemID(preferring: "western") == "western")
    }

    @Test func staleForeignPreferenceFallsBackToDefault() {
        // "western" doesn't exist on Greek — must not silently propagate.
        #expect(Self.greek.resolvedPronunciationSystemID(preferring: "western") == "modern")
    }

    @Test func defaultPronunciationSystemIDIsTheFirstListed() {
        #expect(Self.armenian.defaultPronunciationSystemID == "eastern")
    }
}
