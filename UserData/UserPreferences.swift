import Foundation
import SwiftData

/// User-facing settings (SPEC §4, §9), singleton-by-convention. Wired up by
/// the M9 Settings sheet; the schema exists now so the M8 `ModelContainer`
/// carries all four `@Model` types from the start.
@Model
final class UserPreferences {
    var selectedLanguageID: Int = 0
    var pronunciationSystemID: String = "modern"
    var appearanceRaw: String = "system"
    var paletteID: String = ""
    var customPaletteData: Data?
    var cardFilterRaw: String = ""
    var isShuffled: Bool = false

    init(
        selectedLanguageID: Int = 0, pronunciationSystemID: String = "modern",
        appearanceRaw: String = "system", paletteID: String = "", customPaletteData: Data? = nil,
        cardFilterRaw: String = "", isShuffled: Bool = false
    ) {
        self.selectedLanguageID = selectedLanguageID
        self.pronunciationSystemID = pronunciationSystemID
        self.appearanceRaw = appearanceRaw
        self.paletteID = paletteID
        self.customPaletteData = customPaletteData
        self.cardFilterRaw = cardFilterRaw
        self.isShuffled = isShuffled
    }
}
