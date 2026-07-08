import SwiftUI

/// `TabView` shell with Cards | Quiz, themed via `ThemeManager`.
struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var theme: ThemeManager
    @State private var alphabetStore: AlphabetStore?
    @State private var loadError: String?

    init() {
        let paletteRegistry = (try? PaletteRegistry()) ?? PaletteRegistry(palettes: [])
        _theme = State(initialValue: ThemeManager(paletteRegistry: paletteRegistry, languageDefaultPaletteID: "greek-flag"))
    }

    var body: some View {
        TabView {
            cardsTab
                .tabItem { Label("Cards", systemImage: "rectangle.stack") }
            quizTab
                .tabItem { Label("Quiz", systemImage: "graduationcap.fill") }
        }
        .tint(theme.accent)
        .environment(theme)
        .preferredColorScheme(theme.preferredColorScheme)
        .onAppear { theme.systemColorScheme = colorScheme }
        .onChange(of: colorScheme) { _, newValue in theme.systemColorScheme = newValue }
        .task {
            do {
                let store = AlphabetStore(registry: try LanguageRegistry())
                theme.languageDefaultPaletteID = store.currentManifest.defaultPaletteID
                alphabetStore = store
            } catch {
                loadError = "Failed to load Manifest.json: \(error)"
            }
        }
    }

    @ViewBuilder
    private var cardsTab: some View {
        if let alphabetStore {
            CardsView(manifest: alphabetStore.currentManifest, items: alphabetStore.items)
        } else if let loadError {
            Text(loadError).foregroundStyle(.red)
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private var quizTab: some View {
        if let alphabetStore {
            QuizView(manifest: alphabetStore.currentManifest, items: alphabetStore.items)
        } else if let loadError {
            Text(loadError).foregroundStyle(.red)
        } else {
            ProgressView()
        }
    }
}

#Preview {
    RootView()
}
