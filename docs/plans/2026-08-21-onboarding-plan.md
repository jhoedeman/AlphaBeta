# Onboarding Implementation Plan

Spec: [docs/superpowers/specs/2026-08-21-onboarding-design.md](../superpowers/specs/2026-08-21-onboarding-design.md)

## Phase 1 — Persistence

**`UserData/UserPreferences.swift`**
Add a new field, defaulted so existing SwiftData records migrate cleanly:

```swift
var hasCompletedOnboarding: Bool = false
```

Add it to the memberwise `init` too (with the same default), alongside the
existing fields.

**`UserData/UserPreferencesStore.swift`**
Expose it the same way every other field is exposed:

```swift
private(set) var hasCompletedOnboarding: Bool
```

set in `init` from `record.hasCompletedOnboarding`, plus a setter:

```swift
func setHasCompletedOnboarding(_ value: Bool) {
    hasCompletedOnboarding = value
    record.hasCompletedOnboarding = value
    save()
}
```

**Test:** extend `AlphaBetaTests/UserDataPersistenceTests.swift` with a case
that creates a store, calls `setHasCompletedOnboarding(true)`, re-instantiates
`UserPreferencesStore` against the same context, and asserts the flag
persisted (mirror whatever pattern the existing tests in that file use for
the other boolean/string fields).

## Phase 2 — Onboarding screens

New folder: `Features/Onboarding/`

**`Features/Onboarding/OnboardingView.swift`**
Owns a `@State private var showingLanguageGrid = false` (or a lightweight
internal enum `Step { case intro, languageGrid }`) and switches between the
two screens below. Takes what it needs to complete onboarding as
parameters/closures — `languageRegistry: LanguageRegistry`,
`paletteRegistry: PaletteRegistry`, `alphabetStore: AlphabetStore`,
`preferencesStore: UserPreferencesStore`, and `theme` via
`@Environment(ThemeManager.self)` (same pattern `SettingsSheet` already
uses).

**`Features/Onboarding/IntroScreen.swift`**
- `Image("AppIcon")` (check the actual asset name in `Assets.xcassets` —
  likely referenced elsewhere as `ASSETCATALOG_COMPILER_APPICON_NAME:
  AppIcon` in `project.yml`, but app icons aren't always directly
  `Image()`-loadable from the icon set; if not, fall back to a simple SF
  Symbol or the wordmark alone rather than fighting asset-catalog access)
- Wordmark text "Alpha|Beta"
- Tagline text
- Three `Label`-style rows, each pairing an SF Symbol with its phrase (see
  spec for the three symbol/phrase pairs)
- A full-width `Button("Get Started")` styled with `theme.accent`, calling an
  `onContinue: () -> Void` closure

**`Features/Onboarding/LanguageGridScreen.swift`**
- `LazyVGrid` with 2 `GridItem(.flexible())` columns
- One cell per `languageRegistry.languages` entry
- Each cell: `Text(manifest.nativeName)` large, `Text(manifest.displayName)`
  smaller below, background tinted via
  `paletteRegistry.palette(forID: manifest.defaultPaletteID)?.light.accent`
  (resolve `Color(hex:)` the same way `SettingsSheet.paletteRow` already
  does) at low opacity
- Tap handler on each cell:
  ```swift
  alphabetStore.selectLanguage(id: manifest.id)
  theme.languageDefaultPaletteID = manifest.defaultPaletteID
  preferencesStore.setSelectedLanguage(id: manifest.id)
  preferencesStore.setHasCompletedOnboarding(true)
  ```
  wrapped in a short `withAnimation` (match the `.easeInOut(duration: 0.4)`
  `RootView.selectLanguage` already uses, for visual consistency) with a
  brief scale/highlight effect on the tapped cell before the state change
  propagates
- No "Continue" button, no skip control

**Manual check:** run in Simulator, confirm both screens render, confirm
tapping each of the 10 language cells correctly lands in the Cards tab
showing that language with its default palette active.

## Phase 3 — Wire into RootView

**`App/RootView.swift`**
In `body`, once the existing `if let alphabetStore, let languageRegistry,
let preferencesStore, let streakStore, let userDataStore` loading gate
passes, add one more branch:

```swift
if !preferencesStore.hasCompletedOnboarding {
    OnboardingView(
        languageRegistry: languageRegistry, paletteRegistry: paletteRegistry,
        alphabetStore: alphabetStore, preferencesStore: preferencesStore
    )
} else {
    TabView { /* existing content */ }
}
```

Since `preferencesStore` is `@Observable` and already held in `@State`, this
re-evaluates automatically the moment `setHasCompletedOnboarding(true)` is
called — no extra binding plumbing needed.

**Manual check:** fresh Simulator install (or reset via Phase 4's debug
toggle) shows onboarding before the tab bar; completing it shows the tab bar
without a relaunch.

## Phase 4 — Debug replay toggle

**`Features/Settings/SettingsSheet.swift`**
Add a new section, `#if DEBUG`-gated so it's compiled out of release/
TestFlight builds entirely (not just hidden at runtime):

```swift
#if DEBUG
private var debugSection: some View {
    Section("Debug") {
        Button("Replay Onboarding") {
            preferencesStore.setHasCompletedOnboarding(false)
        }
    }
}
#endif
```

and add `debugSection` to the `Form` in `body`, again `#if DEBUG`-wrapped.

**Manual check:** in a Debug build, tap the row, confirm the Settings sheet
dismisses (or the tab bar swaps out from under it) straight into
`OnboardingView`; confirm the row is absent when building the `Release`
configuration (`xcodebuild -showBuildSettings` or just archive and inspect,
same as the TestFlight build process already in use).

## Out of Scope (carried over from spec)

- No skip button
- No multi-page intro carousel
- No changes to post-onboarding app behavior
