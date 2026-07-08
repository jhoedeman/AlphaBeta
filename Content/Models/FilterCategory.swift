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

    /// Parses a `UserPreferences.cardFilterRaw`-style comma-joined raw-value
    /// list back into a set, per SPEC §4. Unknown entries (e.g. a category
    /// dropped in a later app version) are silently ignored.
    static func set(fromCommaJoinedRawValues raw: String) -> Set<FilterCategory> {
        Set(raw.split(separator: ",").compactMap { FilterCategory(rawValue: String($0)) })
    }
}
