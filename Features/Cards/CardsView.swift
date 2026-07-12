import SwiftUI

/// Cards tab root, per SPEC §5: filter pills + shuffle above, the swipeable
/// deck centered (constrained to 480x640 on iPad), a card-count indicator
/// below, and a friendly empty state when every filter is deselected. Also
/// hosts the top bar's language/settings buttons per SPEC §9.
struct CardsView: View {
    let manifest: LanguageManifest
    let items: [AlphabetItem]
    let languageRegistry: LanguageRegistry
    let paletteRegistry: PaletteRegistry
    let preferencesStore: UserPreferencesStore
    let onSelectLanguage: (LanguageManifest) -> Void

    @State private var viewModel: CardDeckViewModel
    @State private var detailItem: AlphabetItem?
    @State private var showLanguagePicker = false
    @State private var showSettings = false

    @Environment(ThemeManager.self) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var pronunciationSystemID: String {
        viewModel.manifest.resolvedPronunciationSystemID(preferring: preferencesStore.pronunciationSystemID)
    }

    init(
        manifest: LanguageManifest, items: [AlphabetItem], languageRegistry: LanguageRegistry,
        paletteRegistry: PaletteRegistry, preferencesStore: UserPreferencesStore,
        onSelectLanguage: @escaping (LanguageManifest) -> Void
    ) {
        self.manifest = manifest
        self.items = items
        self.languageRegistry = languageRegistry
        self.paletteRegistry = paletteRegistry
        self.preferencesStore = preferencesStore
        self.onSelectLanguage = onSelectLanguage
        _viewModel = State(initialValue: Self.makeViewModel(manifest: manifest, items: items, preferencesStore: preferencesStore))
    }

    /// Rebuilds `viewModel` for a newly-selected manifest without changing
    /// `CardsView`'s own identity (no `.id()` in `RootView` any more).
    /// Forcing a fresh identity used to tear down and recreate this view's
    /// `NavigationStack` on every language switch — which, on iOS 18.4
    /// Simulator, reliably crashed with `NSInternalInconsistencyException`
    /// ("attempt to nest wrapped navigation controllers") because the
    /// language-picker sheet's own `NavigationStack` was still mid-dismissal
    /// on the very bar being torn down. Resetting the view model in place
    /// keeps the `NavigationStack` alive across the switch and avoids the
    /// race entirely.
    private static func makeViewModel(
        manifest: LanguageManifest, items: [AlphabetItem], preferencesStore: UserPreferencesStore
    ) -> CardDeckViewModel {
        let persisted = FilterCategory.set(fromCommaJoinedRawValues: preferencesStore.cardFilterRaw)
            .intersection(manifest.filterCategories)
        let initialFilters = persisted.isEmpty ? Set(manifest.filterCategories) : persisted

        return CardDeckViewModel(
            manifest: manifest, allItems: items,
            initialFilters: initialFilters, initialShuffled: preferencesStore.isShuffled,
            onPreferencesChanged: { filterRaw, isShuffled in
                preferencesStore.setCardPreferences(filterRaw: filterRaw, isShuffled: isShuffled)
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                FilterPillBar(viewModel: viewModel)

                if viewModel.count == 0 {
                    Spacer()
                    Text("Pick at least one category")
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                } else {
                    // Full width, not constrained to 480 — the carousel's
                    // card size is fixed internally, and the iPad's extra
                    // width beyond that fixed size is what becomes peek.
                    // `.id()` here (not on CardsView itself) so switching
                    // languages remounts just the carousel: CardCarouselView
                    // seeds its scroll position from `viewModel.currentIndex`
                    // in `init`, but since `viewModel` is now swapped in
                    // place (see `makeViewModel` above) rather than forcing a
                    // new `CardsView` identity, that `init` was never
                    // re-running — leaving the carousel's scroll state stuck
                    // on the *previous* language's entries and visibly
                    // landing on the wrong (often last) item after a switch.
                    // CardCarouselView owns no NavigationStack, so remounting
                    // it can't reintroduce the nav-bar crash `CardsView`'s
                    // own `.id()` used to cause.
                    CardCarouselView(viewModel: viewModel) { item in
                        detailItem = item
                    }
                    .id(viewModel.manifest.id)
                    .frame(maxWidth: .infinity)

                    Text("\(viewModel.currentIndex + 1) / \(viewModel.count)")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        Text(viewModel.manifest.flagEmoji)
                            .font(.title3)
                    }
                    .accessibilityLabel("Change language")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .sheet(item: $detailItem) { item in
            // iPhone: full-height sheet with a drag handle for the
            // interactive pull-down dismiss SPEC §6 asks for, alongside the
            // chevron button. iPad: a centered form sheet, per the same spec.
            if horizontalSizeClass == .regular {
                ItemDetailSheet(item: item, manifest: viewModel.manifest, allItems: viewModel.allItems, pronunciationSystemID: pronunciationSystemID)
                    .presentationSizing(.form)
            } else {
                ItemDetailSheet(item: item, manifest: viewModel.manifest, allItems: viewModel.allItems, pronunciationSystemID: pronunciationSystemID)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(registry: languageRegistry, currentLanguageID: viewModel.manifest.id, onSelect: onSelectLanguage)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(manifest: viewModel.manifest, paletteRegistry: paletteRegistry, preferencesStore: preferencesStore)
        }
        .onChange(of: manifest.id) { _, _ in
            viewModel = Self.makeViewModel(manifest: manifest, items: items, preferencesStore: preferencesStore)
        }
    }
}
