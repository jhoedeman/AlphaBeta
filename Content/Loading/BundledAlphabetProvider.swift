import Foundation

/// Loads alphabet content from `<fileName>.json` in the given bundle
/// (defaults to the app's main bundle; tests/previews pass `Bundle.module`
/// or a test bundle instead).
struct BundledAlphabetProvider: AlphabetProviding {
    let bundle: Bundle
    let decoder: JSONDecoder

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    func loadAlphabet(for manifest: LanguageManifest) throws -> Alphabet {
        guard let url = bundle.url(forResource: manifest.fileName, withExtension: "json") else {
            throw AlphabetLoadingError.resourceNotFound(fileName: manifest.fileName)
        }
        let data = try Data(contentsOf: url)
        let file = try decoder.decode(AlphabetFile.self, from: data)
        guard let alphabet = file.alphabets.first(where: { $0.language == manifest.id }) else {
            throw AlphabetLoadingError.languageNotInFile(expected: manifest.id, fileName: manifest.fileName)
        }
        return alphabet
    }
}
