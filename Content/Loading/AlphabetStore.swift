import Foundation

/// Caches loaded `Alphabet` content per language so switching tabs doesn't
/// redecode JSON, per SPEC §2/§3. Language switching UI lands in M9; the
/// store's `selectLanguage` API is ready for it ahead of time.
@Observable
final class AlphabetStore {
    private let registry: LanguageRegistry
    private let provider: AlphabetProviding
    private var cache: [Int: Alphabet] = [:]

    private(set) var currentManifest: LanguageManifest
    private(set) var loadError: String?

    /// `registry.languages` always has at least the bundled Greek entry —
    /// enforced by `Manifest.json` and covered by `ContentDecodingTests`.
    init(registry: LanguageRegistry, provider: AlphabetProviding = BundledAlphabetProvider()) {
        self.registry = registry
        self.provider = provider
        currentManifest = registry.languages.first!
        loadCurrentIfNeeded()
    }

    var items: [AlphabetItem] {
        cache[currentManifest.id]?.alphabetItems ?? []
    }

    func selectLanguage(id: Int) {
        guard let manifest = registry.manifest(forID: id) else { return }
        currentManifest = manifest
        loadCurrentIfNeeded()
    }

    private func loadCurrentIfNeeded() {
        guard cache[currentManifest.id] == nil else { return }
        do {
            cache[currentManifest.id] = try provider.loadAlphabet(for: currentManifest)
        } catch {
            loadError = "Failed to load \(currentManifest.displayName): \(error)"
        }
    }
}
