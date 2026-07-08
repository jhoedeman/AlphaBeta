import Foundation

/// One language's full item set, as decoded from `<Language>.json`.
struct Alphabet: Codable, Hashable, Sendable {
    let language: Int
    let alphabetItems: [AlphabetItem]
}

/// Top-level shape of every bundled alphabet JSON file (schema v2).
struct AlphabetFile: Codable, Hashable, Sendable {
    let version: Int
    let alphabets: [Alphabet]
}
