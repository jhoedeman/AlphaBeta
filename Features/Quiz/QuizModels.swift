import Foundation

/// One of the six question shapes `QuizEngine` can generate, per SPEC §7.2.
enum QuestionType: CaseIterable, Hashable, Sendable {
    case glyphToName
    case nameToGlyph
    case wordContains
    case nameToWord
    case caseMatch
    case soundToGlyph
}

/// One selectable answer. `itemIdentifier` lets the engine validate
/// distractors without re-parsing option text.
struct QuizOption: Identifiable, Hashable, Sendable {
    let id = UUID()
    let text: String
    let itemIdentifier: Int
    let isCorrect: Bool
}

/// A single generated multiple-choice question, ready for the quiz UI (M6).
struct QuizQuestion: Identifiable, Hashable, Sendable {
    let id = UUID()
    let type: QuestionType
    let prompt: String
    let correctItemIdentifier: Int
    let options: [QuizOption]
}

/// Supplies per-item accuracy for `QuizEngine`'s adaptive weighting (SPEC
/// §7.2). `nil` means unseen. Kept as a protocol so the pure engine doesn't
/// depend on the SwiftData `ItemProgress` model that lands in M8.
protocol ItemAccuracyProviding {
    func accuracy(for itemIdentifier: Int) -> Double?
}
