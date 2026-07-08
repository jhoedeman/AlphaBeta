import Foundation

/// The kind of alphabet entry. Unrecognized raw values decode to `.unknown`
/// rather than throwing, so future scripts (e.g. Devanagari conjuncts) can
/// ship new type codes without breaking older app versions reading new JSON.
enum ItemType: Int, Hashable, Sendable {
    case letter = 0
    case diphthong = 1
    case combination = 2
    case unknown = -1
}

extension ItemType: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = ItemType(rawValue: raw) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
