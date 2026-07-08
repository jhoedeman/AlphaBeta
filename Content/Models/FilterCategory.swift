import Foundation

/// A card/quiz filter pill. Which categories a language exposes comes from
/// its manifest entry (`filterCategories`) — caseless scripts like Georgian
/// use only `.letters`.
enum FilterCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case capitals
    case lowercase
    case diphthongs
    case combinations
    case letters

    var displayName: String {
        switch self {
        case .capitals: "Capitals"
        case .lowercase: "Lowercase"
        case .diphthongs: "Diphthongs"
        case .combinations: "Combinations"
        case .letters: "Letters"
        }
    }
}
