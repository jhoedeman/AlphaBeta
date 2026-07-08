import SwiftUI

/// M2 shell: `TabView` with Cards | Quiz, themed via `ThemeManager`.
/// Tab contents are placeholders until M3 (Cards) and M6 (Quiz UI).
struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var theme: ThemeManager
    @State private var languages: [LanguageManifest] = []
    @State private var loadError: String?

    init() {
        let paletteRegistry = (try? PaletteRegistry()) ?? PaletteRegistry(palettes: [])
        _theme = State(initialValue: ThemeManager(paletteRegistry: paletteRegistry, languageDefaultPaletteID: "greek-flag"))
    }

    var body: some View {
        TabView {
            cardsPlaceholder
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
                languages = try LanguageRegistry().languages
            } catch {
                loadError = "Failed to load Manifest.json: \(error)"
            }
        }
    }

    private var cardsPlaceholder: some View {
        NavigationStack {
            List {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(languages) { language in
                    Label(language.displayName, systemImage: "character.book.closed")
                }
            }
            .navigationTitle("AlphaBeta")
            .background(theme.background)
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
