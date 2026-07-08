import Foundation

enum AlphabetLoadingError: Error {
    case resourceNotFound(fileName: String)
    case languageNotInFile(expected: Int, fileName: String)
}

/// Abstraction over where alphabet content comes from. v1 ships only
/// `BundledAlphabetProvider`; a future `RemoteAlphabetProvider` (CloudKit
/// public DB) slots in behind this same protocol without touching callers.
protocol AlphabetProviding {
    func loadAlphabet(for manifest: LanguageManifest) throws -> Alphabet
}
