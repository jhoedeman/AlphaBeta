import Foundation
import SwiftData

/// Per-item quiz history, keyed by `(languageID, itemIdentifier)` rather
/// than an object relationship to content (SPEC §2, §4) — content stays
/// out of SwiftData entirely.
@Model
final class ItemProgress {
    var languageID: Int = 0
    var itemIdentifier: Int = 0
    var timesQuizzed: Int = 0
    var timesCorrect: Int = 0
    var lastQuizzedAt: Date?

    init(
        languageID: Int = 0, itemIdentifier: Int = 0,
        timesQuizzed: Int = 0, timesCorrect: Int = 0, lastQuizzedAt: Date? = nil
    ) {
        self.languageID = languageID
        self.itemIdentifier = itemIdentifier
        self.timesQuizzed = timesQuizzed
        self.timesCorrect = timesCorrect
        self.lastQuizzedAt = lastQuizzedAt
    }

    var accuracy: Double? {
        timesQuizzed > 0 ? Double(timesCorrect) / Double(timesQuizzed) : nil
    }
}
