import Foundation

/// One pronunciation system's text for an item (e.g. the "modern" entry in
/// a Greek item's pronunciation map). Sub-fields are optional; a system with
/// no data for a given field simply omits it rather than encoding null.
struct PronunciationEntry: Codable, Hashable, Sendable {
    let full: String?
    let short: String?
    let letterName: String?
}
