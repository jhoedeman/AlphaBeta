import Foundation
import SwiftData

/// SwiftData-backed settings facade (SPEC §4, §9) — the M9 counterpart to
/// `SwiftDataUserDataStore`. Loads the singleton `UserPreferences` record
/// once and exposes its fields as read-only state plus explicit setter
/// methods, mirroring `StreakStore`'s "mutate via method, not property
/// observer" convention so init doesn't accidentally re-persist loaded data.
@Observable
final class UserPreferencesStore {
    private let context: ModelContext
    private let record: UserPreferences

    private(set) var selectedLanguageID: Int
    private(set) var pronunciationSystemID: String
    private(set) var appearanceRaw: String
    private(set) var paletteID: String
    private(set) var customPaletteData: Data?
    private(set) var cardFilterRaw: String
    private(set) var isShuffled: Bool

    init(context: ModelContext) {
        self.context = context
        let record = context.fetchOrCreateUserPreferences()
        self.record = record
        selectedLanguageID = record.selectedLanguageID
        pronunciationSystemID = record.pronunciationSystemID
        appearanceRaw = record.appearanceRaw
        paletteID = record.paletteID
        customPaletteData = record.customPaletteData
        cardFilterRaw = record.cardFilterRaw
        isShuffled = record.isShuffled
    }

    func setSelectedLanguage(id: Int) {
        selectedLanguageID = id
        record.selectedLanguageID = id
        save()
    }

    func setPronunciationSystem(id: String) {
        pronunciationSystemID = id
        record.pronunciationSystemID = id
        save()
    }

    func setAppearance(_ raw: String) {
        appearanceRaw = raw
        record.appearanceRaw = raw
        save()
    }

    /// `id == ""` means "use the language default" (SPEC §8.1).
    func setPalette(id: String) {
        paletteID = id
        record.paletteID = id
        save()
    }

    func setCustomPalette(_ data: Data?) {
        customPaletteData = data
        record.customPaletteData = data
        save()
    }

    func setCardPreferences(filterRaw: String, isShuffled: Bool) {
        cardFilterRaw = filterRaw
        self.isShuffled = isShuffled
        record.cardFilterRaw = filterRaw
        record.isShuffled = isShuffled
        save()
    }

    private func save() {
        try? context.save()
    }
}
