import Foundation

enum LanguageRegistryError: Error {
    case manifestNotFound
}

/// Loads the bundled `Manifest.json` language list once and exposes it for
/// the language picker, `AlphabetStore`, and anywhere else that needs to
/// enumerate or look up a language's manifest entry.
struct LanguageRegistry {
    let languages: [LanguageManifest]

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) throws {
        guard let url = bundle.url(forResource: "Manifest", withExtension: "json") else {
            throw LanguageRegistryError.manifestNotFound
        }
        let data = try Data(contentsOf: url)
        self.languages = try decoder.decode([LanguageManifest].self, from: data)
    }

    init(languages: [LanguageManifest]) {
        self.languages = languages
    }

    func manifest(forID id: Int) -> LanguageManifest? {
        languages.first { $0.id == id }
    }

    /// Languages grouped by `scriptFamily`, preserving manifest order within
    /// each group — drives the language picker's sectioned list.
    var groupedByScriptFamily: [(scriptFamily: String, languages: [LanguageManifest])] {
        var order: [String] = []
        var groups: [String: [LanguageManifest]] = [:]
        for language in languages {
            if groups[language.scriptFamily] == nil {
                order.append(language.scriptFamily)
                groups[language.scriptFamily] = []
            }
            groups[language.scriptFamily]?.append(language)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }
}
