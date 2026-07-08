import Foundation

/// One row of the bundled `Manifest.json` language registry. Everything
/// language-specific that isn't per-item content lives here — display name,
/// script family, available filters/pronunciation systems, default palette —
/// so adding a language never means touching Swift code, only JSON.
struct LanguageManifest: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let code: String
    let displayName: String
    let nativeName: String
    let scriptFamily: String
    let fileName: String
    let readingDirection: ReadingDirection
    let hasLetterCase: Bool
    let pronunciationSystems: [PronunciationSystem]
    let filterCategories: [FilterCategory]
    let defaultPaletteID: String
    let flagEmoji: String

    /// The manifest's first-listed pronunciation system is the default,
    /// per SPEC §3.2's resolution rule.
    var defaultPronunciationSystemID: String {
        pronunciationSystems.first?.id ?? "modern"
    }

    /// The user's preferred system if this language actually offers it,
    /// else the manifest default — a language switch can leave a stale
    /// preference (e.g. Armenian's "eastern") that doesn't apply to Greek.
    func resolvedPronunciationSystemID(preferring id: String) -> String {
        pronunciationSystems.contains { $0.id == id } ? id : defaultPronunciationSystemID
    }
}
