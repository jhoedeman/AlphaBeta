import Foundation

enum PaletteRegistryError: Error {
    case resourceNotFound
}

/// Loads the bundled `Palettes.json` palette list.
struct PaletteRegistry {
    let palettes: [Palette]

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) throws {
        guard let url = bundle.url(forResource: "Palettes", withExtension: "json") else {
            throw PaletteRegistryError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        self.palettes = try decoder.decode([Palette].self, from: data)
    }

    init(palettes: [Palette]) {
        self.palettes = palettes
    }

    func palette(forID id: String) -> Palette? {
        palettes.first { $0.id == id }
    }
}
