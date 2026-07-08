import Foundation
import SwiftData

/// One completed (or abandoned) quiz attempt, per SPEC §4. `completedAt ==
/// nil` means abandoned — doesn't count toward streaks.
@Model
final class QuizSession {
    var languageID: Int = 0
    var startedAt: Date = Date.now
    var completedAt: Date?
    var score: Int = 0
    var questionCount: Int = 10
    var filtersUsedRaw: String = ""

    init(
        languageID: Int = 0, startedAt: Date = .now, completedAt: Date? = nil,
        score: Int = 0, questionCount: Int = 10, filtersUsedRaw: String = ""
    ) {
        self.languageID = languageID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.score = score
        self.questionCount = questionCount
        self.filtersUsedRaw = filtersUsedRaw
    }
}
