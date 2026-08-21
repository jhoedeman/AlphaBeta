# Onboarding Design

## Goal

First-time launch currently drops users straight into the Cards tab with
Greek preselected, with no explanation of what the app does. Add a two-screen
onboarding flow: a short value-prop intro, then a language picker that also
serves as the natural "get started" action.

## Flow & Entry Point

`RootView` currently gates its `TabView` behind a loading check (`if let
alphabetStore, let languageRegistry, ...`). Add a new gate above it: once
loaded, if `preferencesStore.hasCompletedOnboarding == false`, show
`OnboardingView` instead of the `TabView`. `OnboardingView` owns its own
two-screen navigation internally (`IntroScreen` → `LanguageGridScreen`) and
is dismissed by flipping the flag, which `RootView` observes reactively (no
separate dismiss callback needed — same pattern as how `theme` and
`alphabetStore` already drive `RootView`'s body via `@State`/environment).

### Persistence

Add `hasCompletedOnboarding: Bool` (default `false`) to the `UserPreferences`
SwiftData model, alongside the existing `selectedLanguageID`,
`appearanceRaw`, `paletteID`, etc. Expose it through `UserPreferencesStore`
the same way those fields are exposed (a stored property backed by a setter
that writes through to SwiftData).

### Debug replay

Add a `#if DEBUG`-only row to `SettingsSheet`'s `aboutSection` (or its own
debug section): "Replay Onboarding", which calls
`preferencesStore.setHasCompletedOnboarding(false)`. Because `RootView`
re-evaluates its gate whenever `preferencesStore` changes, this immediately
swaps back to `OnboardingView` without relaunching the app or clearing
SwiftData. Wrapped in `#if DEBUG` so it never ships to TestFlight/App Store
builds.

## Screen 1 — Value Intro

Content:
- App icon (reuse `AppIcon` asset)
- "Alpha|Beta" wordmark
- Tagline: "Learn to read Greek, Cyrillic, and more — one letter at a time."
- Three bullets, each an SF Symbol + short phrase, reusing icons already used
  elsewhere in the app for visual continuity:
  - `rectangle.stack` — "Swipeable flashcards for every letter"
  - `graduationcap.fill` — "An adaptive quiz that learns what you're still
    working on"
  - `flame.fill` — "Daily streaks to keep you coming back"
- Full-width "Get Started" button at the bottom, themed with the current
  accent color (`theme.accent`), advances to Screen 2

## Screen 2 — Language Grid

- 2-column grid, one cell per entry in `Manifest.json` (order as-is, Greek
  first)
- Each cell shows:
  - `nativeName` (e.g. `Ελληνικά`, `Русский`) large and centered — already
    present in `LanguageManifest`, no new content needed
  - `displayName` (e.g. "Greek") smaller, below
  - Background subtly tinted using that language's `defaultPaletteID`,
    resolved through the existing `PaletteRegistry` (same registry
    `ThemeManager` already uses) — reuses `Palettes.json`, no new palette
    data needed
- Tapping a cell: brief highlight/scale animation, then in one action:
  - `alphabetStore.selectLanguage(id:)`
  - `theme.languageDefaultPaletteID = manifest.defaultPaletteID`
  - `preferencesStore.setSelectedLanguage(id:)`
  - `preferencesStore.setHasCompletedOnboarding(true)`
- No "Continue" button and no skip affordance — selecting a language is the
  action that completes onboarding, matching how deliberate and short (10
  options) this choice is.

## Out of Scope

- Skipping onboarding entirely (explicitly rejected — the language choice is
  meant to be seen)
- Multi-page value-prop carousel (one screen was chosen over a 2-3 screen
  carousel to keep it fast for beta testers)
- Any changes to what happens after onboarding completes — user lands in the
  existing `TabView` exactly as `selectLanguage` already behaves today
