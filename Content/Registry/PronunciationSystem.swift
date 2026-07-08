import Foundation

/// One selectable pronunciation tradition for a language (era, region, or
/// register) — e.g. Greek's `modern`/`koine`, Armenian's `eastern`/`western`.
struct PronunciationSystem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
}
