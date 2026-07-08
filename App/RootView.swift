import SwiftData
import SwiftUI

/// `TabView` shell with Cards | Quiz, themed via `ThemeManager`.
struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var theme: ThemeManager
    @State private var paletteRegistry: PaletteRegistry
    @State private var languageRegistry: LanguageRegistry?
    @State private var alphabetStore: AlphabetStore?
    @State private var loadError: String?
    @State private var streakStore: StreakStore?
    @State private var userDataStore: SwiftDataUserDataStore?
    @State private var preferencesStore: UserPreferencesStore?
    @State private var selectedTab = 0

    init() {
        let paletteRegistry = (try? PaletteRegistry()) ?? PaletteRegistry(palettes: [])
        _paletteRegistry = State(initialValue: paletteRegistry)
        _theme = State(initialValue: ThemeManager(paletteRegistry: paletteRegistry, languageDefaultPaletteID: "greek-flag"))
    }

    var body: some View {
        Group {
            // Gate the *entire* TabView behind one loading check rather than
            // letting each tab independently switch between `ProgressView()`
            // and its real content — doing that per-tab risks a tab whose
            // content type flips while it's the visible one, which can leave
            // its UIKit-hosted view showing a stale snapshot instead of
            // picking up the new content.
            if let alphabetStore, let languageRegistry, let preferencesStore, let streakStore, let userDataStore {
                TabView(selection: $selectedTab) {
                    CardsView(
                        manifest: alphabetStore.currentManifest, items: alphabetStore.items,
                        languageRegistry: languageRegistry, paletteRegistry: paletteRegistry,
                        preferencesStore: preferencesStore, onSelectLanguage: selectLanguage
                    )
                    .id(alphabetStore.currentManifest.id)
                    .tabItem { Label("Cards", systemImage: "rectangle.stack") }
                    .tag(0)

                    QuizView(
                        manifest: alphabetStore.currentManifest, items: alphabetStore.items,
                        streakStore: streakStore, userDataStore: userDataStore,
                        pronunciationSystemID: preferencesStore.pronunciationSystemID
                    )
                    .id(alphabetStore.currentManifest.id)
                    .tabItem { Label("Quiz", systemImage: "graduationcap.fill") }
                    .tag(1)
                }
                .tint(theme.accent)
            } else if let loadError {
                Text(loadError).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .environment(theme)
        .preferredColorScheme(theme.preferredColorScheme)
        .onAppear { theme.systemColorScheme = colorScheme }
        .onChange(of: colorScheme) { _, newValue in theme.systemColorScheme = newValue }
        .task {
            do {
                let registry = try LanguageRegistry()
                languageRegistry = registry
                let store = AlphabetStore(registry: registry)

                let preferences = UserPreferencesStore(context: modelContext)
                preferencesStore = preferences
                applyPersistedTheme(from: preferences)
                store.selectLanguage(id: preferences.selectedLanguageID)
                theme.languageDefaultPaletteID = store.currentManifest.defaultPaletteID
                alphabetStore = store

                let record = modelContext.fetchOrCreateStreakRecord()
                streakStore = StreakStore(
                    currentStreak: record.currentStreak, longestStreak: record.longestStreak,
                    lastCompletedDay: record.lastCompletedDay
                )
                userDataStore = SwiftDataUserDataStore(context: modelContext, languageID: store.currentManifest.id)
            } catch {
                loadError = "Failed to load Manifest.json: \(error)"
            }
        }
    }

    private func applyPersistedTheme(from preferences: UserPreferencesStore) {
        if let appearance = ThemeManager.Appearance(rawValue: preferences.appearanceRaw) {
            theme.appearance = appearance
        }
        if !preferences.paletteID.isEmpty {
            theme.paletteOverrideID = preferences.paletteID
        }
        if let data = preferences.customPaletteData, let decoded = try? JSONDecoder().decode(Palette.self, from: data) {
            theme.customPalette = decoded
        }
    }

    /// Language sheet selection per SPEC §9: switches content, resets Cards
    /// filters, and animates the recolor (unless the user has a custom/stock
    /// palette override, which `ThemeManager.activePalette` already respects).
    private func selectLanguage(_ manifest: LanguageManifest) {
        withAnimation(.easeInOut(duration: 0.4)) {
            alphabetStore?.selectLanguage(id: manifest.id)
            theme.languageDefaultPaletteID = manifest.defaultPaletteID
        }
        preferencesStore?.setSelectedLanguage(id: manifest.id)
        if let alphabetStore {
            userDataStore = SwiftDataUserDataStore(context: modelContext, languageID: alphabetStore.currentManifest.id)
        }
    }
}

#Preview {
    RootView()
}
