import SwiftUI

/// Two-screen first-run flow: a value-prop intro, then a language picker
/// that doubles as the action that completes onboarding. Shown by `RootView`
/// in place of the main `TabView` while `preferencesStore.hasCompletedOnboarding`
/// is `false`.
struct OnboardingView: View {
    let languageRegistry: LanguageRegistry
    let paletteRegistry: PaletteRegistry
    let alphabetStore: AlphabetStore
    let preferencesStore: UserPreferencesStore

    @Environment(ThemeManager.self) private var theme
    @State private var showingLanguageGrid = false

    var body: some View {
        Group {
            if showingLanguageGrid {
                LanguageGridScreen(
                    languageRegistry: languageRegistry, paletteRegistry: paletteRegistry,
                    onSelect: complete
                )
                .transition(.move(edge: .trailing))
            } else {
                IntroScreen {
                    withAnimation(.easeInOut) { showingLanguageGrid = true }
                }
                .transition(.move(edge: .leading))
            }
        }
    }

    private func complete(with manifest: LanguageManifest) {
        alphabetStore.selectLanguage(id: manifest.id)
        theme.languageDefaultPaletteID = manifest.defaultPaletteID
        preferencesStore.setSelectedLanguage(id: manifest.id)
        preferencesStore.setHasCompletedOnboarding(true)
    }
}
