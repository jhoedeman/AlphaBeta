import SwiftUI

/// `TabView` shell with Cards | Quiz, themed via `ThemeManager`. Quiz stays a
/// placeholder until M6.
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
            quizPlaceholder
                .tabItem { Label("Quiz", systemImage: "questionmark.circle") }
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

    private var quizPlaceholder: some View {
        NavigationStack {
            Text("Quiz coming in M5/M6")
                .foregroundStyle(theme.textSecondary)
                .navigationTitle("Quiz")
                .background(theme.background)
        }
    }
}

#Preview {
    RootView()
}
