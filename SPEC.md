# AlphaBeta — Build Specification v1.0

A pure-SwiftUI iPhone/iPad app for exploring non-Latin alphabets. Ships with nine languages — Greek, six Cyrillic (Russian, Ukrainian, Belarusian, Serbian, Bulgarian, Macedonian), Armenian, and Georgian — and is architected for Arabic script, Hebrew, Devanagari, kana, Hangul, and more (roadmap in §11.1).

---

## 1. Platform & Stack

- **Targets:** iPhone and iPad, portrait and landscape. Single app target.
- **Minimum OS:** iOS/iPadOS 18.0.
- **UI:** 100% SwiftUI. No UIKit view controllers (UIKit types allowed only where unavoidable, e.g. haptics via `UIImpactFeedbackGenerator`).
- **Persistence:** SwiftData with CloudKit sync (private database) for **user data only** — quiz history, per-item progress, streaks, preferences.
- **Content:** Alphabet data is bundled JSON, loaded read-only into value-type models. **Alphabet content never goes into SwiftData.**
- **CloudKit container:** `iCloud.com.JohnHoedeman.AlphaBeta` (bundle ID `com.JohnHoedeman.AlphaBeta`, per the existing project).
- **Legacy code:** an older UIKit/storyboard/Core Data version lives in the sibling repo `../AlphaBetaV1` (renamed; its bundle ID is now `com.JohnHoedeman.AlphaBetaV1`, freeing the canonical ID above for this app). **Do not retrofit it.** Build fresh in this folder; the legacy `Models/Alphabets.swift` and `LanguageData.plist` may be consulted for reference but nothing UIKit carries over.
- **Business model:** Free, no StoreKit in v1. Keep alphabet loading behind a registry so per-alphabet IAP gating can be added later without refactoring.
- **Dependencies:** None. No third-party packages.

### CloudKit + SwiftData rules (critical — build errors otherwise)
- Every `@Model` property must be optional **or** have a default value.
- No `@Attribute(.unique)` constraints.
- All relationships optional, with inverse relationships defined.
- Use `ModelConfiguration(cloudKitDatabase: .automatic)`; enable the iCloud + CloudKit capability and remote-notifications background mode.
- App must function fully with iCloud unavailable (local store still works; sync is a bonus).

---

## 2. Architecture Overview

```
AlphaBeta/
├── App/
│   ├── AlphaBetaApp.swift          # @main, ModelContainer, ThemeManager injection
│   └── RootView.swift              # TabView: Cards | Quiz
├── Content/                        # Static alphabet content (value types, not SwiftData)
│   ├── Models/                     # AlphabetItem, Pronunciations, Language, etc.
│   ├── Loading/                    # AlphabetProviding protocol, BundledAlphabetProvider
│   ├── Registry/                   # LanguageRegistry, LanguageManifest
│   └── Resources/                  # Manifest.json, Greek.json, Russian.json (+ future …)
├── UserData/                       # SwiftData models + stores
│   ├── ItemProgress.swift
│   ├── QuizSession.swift
│   ├── UserPreferences.swift
│   └── StreakStore.swift           # streak computation logic
├── Features/
│   ├── Cards/                      # CardsView, CardDeck, SwipeableCard, FilterPillBar
│   ├── Detail/                     # ItemDetailSheet
│   ├── Quiz/                       # QuizSetupView, QuizView, QuizEngine, QuizResultsSheet
│   └── Settings/                   # SettingsSheet, LanguagePickerSheet
├── Theme/
│   ├── Theme.swift                 # semantic color tokens
│   ├── ThemeManager.swift          # @Observable, resolves active palette
│   └── Palettes/                   # per-language defaults + custom
└── Support/                        # extensions, haptics, confetti, etc.
```

Principles:

- **Content vs. state separation.** `AlphabetItem` etc. are immutable `Codable` structs keyed by stable integer `identifier`. User progress references items by `(languageID, identifier)` — never by object relationship. This keeps CloudKit records tiny and content freely updatable.
- **Everything language-driven comes from a manifest**, not hardcoded: display name, script family, reading direction, filter categories, available pronunciation systems, default palette, whether the script has letter case. Greek is just the first manifest entry.
- **Remote-ready loading.** All content access goes through `AlphabetProviding`. v1 ships only `BundledAlphabetProvider`; a future `RemoteAlphabetProvider` (CloudKit public DB) slots in behind the same protocol.

---

## 3. Content Data Model

### 3.1 JSON schema (matches shipped `Greek.json` exactly)

Top level: `{ "version": Int, "alphabets": [Alphabet] }` — shipped `Greek.json` is `version: 2`.
Alphabet: `{ "language": Int, "alphabetItems": [AlphabetItem] }`

`AlphabetItem` fields (all optional unless noted):

| Field | Type | Notes |
|---|---|---|
| `identifier` | Int, required | Stable unique key; progress tracking joins on this |
| `itemType` | Int, required | 0 = letter, 1 = diphthong, 2 = letter combination |
| `englishName` | String, required | "Alpha", "ai", "gg" |
| `foreignLetter` | String, required | The glyph(s): "Α", "αι", "γγ" |
| `exampleWord` | String | "Άλογο, which means 'horse'" |
| `isVowel` | Bool | Drives future vowel/consonant filtering |
| `pronunciations` | object | See 3.2 |
| `languageSubtype` | Int? | Reserved (0 or null in Greek data) |
| `foreignLetterName` | String | Native name: "Άλφα" |
| `markedVersion` / `markedCaseEquivalent` | String | Accented forms (Greek vowels: "Ά", "ά") |
| `caseEquivalent` | String | Opposite-case form ("Α" → "α") |
| `leadingCaseEquivalent`, `middleCaseEquivalent`, `endingCaseEquivalent` | String | Positional forms. Greek: sigma family (Σ→ς ending; ς→σ leading/middle). **Also the hook for Arabic contextual forms later.** |
| `lowercaseEnglishName` | String | e.g. "beta" |
| `explanation` | String | Used on diphthongs/combinations ("This is a combination of…") |

**Shipped datasets** (all schema v2; language ID / item count):

| File | ID | Items | Notes |
|---|---|---|---|
| Greek | 0 | 62 | 24 caps, 25 lower (incl. sigma teliko), 6 diphthongs, 7 combinations |
| Russian | 1 | 66 | 33 case pairs; ъ/ь/ы use contains-style example words (nothing starts with them) |
| Ukrainian | 2 | 66 | г = 'h' (false friend called out); ґ, є, ї, apostrophe-instead-of-ъ notes |
| Belarusian | 3 | 64 | ў (short u); о only under stress; шч instead of щ |
| Serbian | 4 | 60 | Vuk's letters ђ ј љ њ ћ џ; no signs; fully phonemic |
| Bulgarian | 5 | 60 | ъ is a true vowel ("er golyam"); щ = 'sht'; ь only in ьо |
| Macedonian | 6 | 62 | ѓ ќ ѕ unique letters |
| Armenian | 7 | 78 | 38 case pairs + ու (diphthong) + և (combination); `eastern` + `western` systems on every item; Ւ has no example word (historical letter) |
| Georgian | 8 | 33 | Caseless (`hasLetterCase: false`) — single items, no `caseEquivalent`; ejective/aspirate pairs cross-referenced |

Non-Russian Slavic, Armenian, and Georgian example words/glosses are first-draft content — flag for native-speaker review before App Store release (tracked in §12).

### 3.2 Pronunciations object (schema v2: system-keyed map)

`pronunciations` is a dictionary keyed by pronunciation-system ID (era, regional tradition, or register — see 3.5), so new languages and systems never require schema changes:

```json
"pronunciations": {
  "modern": { "full": "…long explanation…", "short": "a long 'a,' as in 'father'", "letterName": "…" },
  "koine":  { "full": "…" }
}
```

- Sub-keys per system (all optional): `full`, `short`, `letterName`.
- Systems with no data are omitted entirely (no nulls). Greek currently ships `modern` only (`full` on all 62 items, `short` on the 49 letters).
- Keys are open strings. Decode as `[String: PronunciationEntry]` — unknown keys must survive decoding untouched.

```swift
struct PronunciationEntry: Codable, Hashable {
    let full: String?
    let short: String?
    let letterName: String?
}
// on AlphabetItem: let pronunciations: [String: PronunciationEntry]
```

**System handling:** map keys are **pronunciation-system IDs** — historical eras for Greek (`modern`, `koine`, `ancient`, plus letter-name-only `fraternity`), regional traditions for others (Armenian `eastern`/`western`), registers for others still (Arabic `quranic`). No hardcoded enum: IDs and display names come from the manifest's `pronunciationSystems` (§3.4); the settings picker shows only those (Greek v1: Modern only, control still present but single-option). Resolution rule: requested system → the manifest's first-listed (default) system → any populated one. Never show an empty pronunciation.

**Legacy note:** `Greek-V1.json` in the repo preserves the retired flat-key format (`modernPronunciation`, `koineShortPronunciation`, …, `version: 1`) for reference only. The app decodes v2 exclusively; do not add v1 support.

### 3.3 Swift content types

```swift
struct AlphabetFile: Codable { let version: Int; let alphabets: [Alphabet] }
struct Alphabet: Codable { let language: Int; let alphabetItems: [AlphabetItem] }

struct AlphabetItem: Codable, Identifiable, Hashable {
    let identifier: Int            // id
    let itemType: ItemType         // enum ItemType: Int, Codable { case letter=0, diphthong=1, combination=2 }
    let englishName: String
    let foreignLetter: String
    // … all remaining fields as optionals, matching 3.1
}
```

Derived helpers on `AlphabetItem`: `isCapital` (letter whose `englishName` starts uppercase — or better: capital iff its `caseEquivalent` is lowercase; Greek naming convention is capitalized English name = capital letter, e.g. "Alpha" vs "alpha"), `category: FilterCategory`, `caseSiblings(in:)` — resolves `caseEquivalent`/`endingCaseEquivalent` glyphs back to their `AlphabetItem`s by matching `foreignLetter`.

### 3.4 LanguageManifest & registry

```swift
struct LanguageManifest: Codable, Identifiable {
    let id: Int                      // matches JSON "language" (Greek = 0)
    let code: String                 // "el"
    let displayName: String          // "Greek", "Russian", "Ukrainian"
    let nativeName: String           // "Ελληνικά"
    let scriptFamily: String         // "greek", "cyrillic", "arabic", "devanagari", "kana"…
    let fileName: String             // "Greek" (→ Greek.json in bundle)
    let readingDirection: ReadingDirection   // .leftToRight / .rightToLeft
    let hasLetterCase: Bool          // false for Arabic, Hebrew, Korean, Thai…
    let pronunciationSystems: [PronunciationSystem]  // ordered; first = default. Greek: [modern]
    let filterCategories: [FilterCategory]   // Greek: [.capitals, .lowercase, .diphthongs, .combinations]
                                             // caseless scripts use [.letters] (Georgian)
    let defaultPaletteID: String     // "greek-flag"
    let flagEmoji: String            // "🇬🇷"
}

struct PronunciationSystem: Codable, Identifiable, Hashable {
    let id: String                   // key into item pronunciation maps: "modern", "koine", "eastern"…
    let displayName: String          // "Modern", "Koine", "Eastern Armenian"
}
```

`LanguageRegistry` loads a bundled `Manifest.json` array (shipped in this repo with Greek and Russian entries). Adding a language later = add JSON + manifest entry + palette. **RTL hook:** when `readingDirection == .rightToLeft`, multi-character items (diphthongs/combinations) render a subtle "read right-to-left ←" hint on cards and detail pages.

### 3.5 Script families & language variants

Two orthogonal dimensions handle scripts shared by multiple languages:

1. **Different letter inventories → separate datasets.** Cyrillic is not one alphabet: Russian (ё, ъ, ы, э), Ukrainian (і, ї, є, ґ), Serbian (ђ, ј, љ, њ, ћ, џ), Bulgarian, and Macedonian (ѓ, ѕ, ќ) each get their own JSON + manifest entry — full first-class languages with their own flag palette, filters, example words, and progress. Shared glyphs still differ per language (г = 'g' Russian / 'h' Ukrainian; щ = 'shch' Russian / 'sht' Bulgarian; ъ = silent sign Russian / vowel Bulgarian), so sharing one dataset would fork nearly every field. The `scriptFamily` field groups them in the language picker ("Cyrillic ▸ Russian, Ukrainian, …"). Same pattern for the Arabic script family (Arabic, Persian, Urdu, Pashto) and Devanagari (Hindi, Marathi, Nepali, Sanskrit). If cross-file duplication gets tedious, per-language JSONs can be generated from a master script-family source at authoring time — a tooling concern, invisible to the app.

2. **Same inventory, different pronunciations → pronunciation systems** (the era mechanism, generalized). Pronunciation-map keys are open strings: Greek uses `modern`/`koine`/`ancient` (historical eras); Armenian uses `eastern`/`western` (regional traditions) for the same 38 letters. The manifest's `pronunciationSystems` provides IDs + display names; the settings picker renders whatever the language declares.

The reserved `languageSubtype` field on items stays reserved (unused) under this model.

`AlphabetProviding`:

```swift
protocol AlphabetProviding {
    func loadAlphabet(for manifest: LanguageManifest) throws -> Alphabet
}
```

Loaded alphabets are cached in an `@Observable AlphabetStore` environment object.

---

## 4. User Data (SwiftData + CloudKit)

```swift
@Model final class UserPreferences {        // singleton-by-convention (fetch first, else create)
    var selectedLanguageID: Int = 0
    var pronunciationSystemID: String = "modern"   // per current language; reset to manifest default on language switch
    var appearanceRaw: String = "system"     // system | light | dark
    var paletteID: String = ""               // "" = use language default
    var customPaletteData: Data? = nil       // user-built palette, Codable blob
    var cardFilterRaw: String = ""           // enabled FilterCategory raw values, per current language
    var isShuffled: Bool = false
}

@Model final class ItemProgress {
    var languageID: Int = 0
    var itemIdentifier: Int = 0
    var timesQuizzed: Int = 0
    var timesCorrect: Int = 0
    var lastQuizzedAt: Date? = nil
}

@Model final class QuizSession {
    var languageID: Int = 0
    var startedAt: Date = Date.now
    var completedAt: Date? = nil             // nil = abandoned; doesn't count for streak
    var score: Int = 0
    var questionCount: Int = 10
    var filtersUsedRaw: String = ""
}

@Model final class StreakRecord {            // singleton-by-convention
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCompletedDay: Date? = nil        // start-of-day in user's calendar
}
```

**Streak logic (`StreakStore`):** on quiz completion, let `today = Calendar.current.startOfDay(for: .now)`. If `lastCompletedDay == today` → no change. If `== yesterday` → `currentStreak += 1`. Else → `currentStreak = 1`. Update `longestStreak = max(...)`, set `lastCompletedDay = today`. On app launch/foreground, if `lastCompletedDay < yesterday`, display current streak as 0 (don't mutate until next completion). Timezone changes resolve via the user's current calendar. **Unit-test this exhaustively** (same-day double quiz, gap day, DST, year boundary).

Because CloudKit merges can duplicate the "singleton" models, always fetch-and-merge: read all, keep the most favorable/most recent, delete extras.

---

## 5. Feature: Cards View (Tab 1)

### Layout
- Top bar: language button (globe or current flag emoji, top-left) and settings gear (top-right).
- Below: `FilterPillBar` — pills from the manifest's `filterCategories` (Greek: Capitals, Lowercase, Diphthongs, Combos). Horizontally scrolling if needed. Multi-select; all selected by default; tapping toggles with a spring animation and haptic. If the user deselects all, show a friendly empty state ("Pick at least one category"). Pills use theme accent when active.
- Shuffle toggle button (e.g. `shuffle` SF Symbol) at the trailing end of the pill bar. Reshuffles on each activation.
- Center: the card deck. Card count indicator ("14 / 35") subtly below the deck.

### Deck behavior ("Tinder look, nothing is discarded")
- Deck is the filtered, ordered item list. Default order: JSON order (alphabetical); shuffle mode randomizes.
- Top card is draggable. Drag translates and rotates the card (rotation ≈ `translation.width / 20` degrees, anchored below center). Beneath it, the next 2 cards peek with slight scale/offset (stacked look).
- Swipe left past threshold (~1/3 card width or high velocity) → card animates off-screen left, deck advances to **next** item; the card re-enters the bottom of the stack. Swipe right → **previous** item. Below threshold → spring back.
- The deck **wraps around** (after the last item comes the first).
- Light impact haptic on every completed swipe.
- Tap on the top card → detail sheet (Section 6).

### Card face
- Huge `foreignLetter` glyph, centered (SF font, `.rounded` optional; scale to fit — combinations like "γγ" must fit).
- Below: `englishName`; below that, `foreignLetterName` in secondary style.
- Bottom edge, small: case-sibling glyphs when present (on "Σ": `σ  ς`), and the item's category label ("Diphthong").
- Marked version (e.g. "Ά") shown as a small corner badge on vowels that have one.
- Card uses theme surface color, large corner radius (~28pt), soft shadow.

### iPad
- Constrain card size: `.frame(maxWidth: 480, maxHeight: 640)` centered; whitespace fills the rest. Same interaction. Regular-width layouts may show the pill bar centered.

---

## 6. Feature: Item Detail

### Presentation
- iPhone: full-screen cover that **slides up from the bottom**. Implement as `.fullScreenCover` with a custom drag-to-dismiss (interactive pull-down on a top grab region / whole scroll view at top), or a full-height `.sheet(detents: [.large])` — choose whichever gives: pull-down dismiss ✅, chevron-down button (top corner) ✅.
- iPad: form sheet (`.sheet` with `.presentationSizing(.form)`), dismissable by tapping outside ✅, pull-down ✅, chevron button ✅.

### Content (top to bottom)
1. Chevron-down dismiss button, top-trailing.
2. Hero glyph: `foreignLetter` very large, theme accent color. If `markedVersion` exists, show it beside/behind at smaller scale with caption "with accent".
3. `englishName` (title) + `foreignLetterName` (subtitle, native script).
4. Metadata chips row: category (Letter/Diphthong/Combination), Vowel/Consonant, capital/lowercase where applicable.
5. **Pronunciation** section: the selected system's `full` text; its `short` as a highlighted one-liner ("Sounds like: a long 'a,' as in 'father'") when present. System label (e.g. "Modern") shown if the language declares more than one. Speaker button slot: **present in layout but hidden in v1** (audio designed-for, not shipped — see §11).
6. **Example word** section: parse `exampleWord` strings of the form "Άλογο, which means 'horse'" into word + meaning for nicer typography (fallback: show raw string). Native word rendered large.
7. **Explanation** section (when present — diphthongs/combinations).
8. **Case forms** section (letters only, per John's requirement): smaller, lower down, the related forms resolved as tappable mini-cards — e.g. detail for "Σ" shows σ (lowercase) and ς (final form / sigma teliko) with labels; tapping one pushes/replaces to that item's detail. Uses `caseEquivalent`, `endingCaseEquivalent`, `leadingCaseEquivalent`, `middleCaseEquivalent`. Not shown for diphthongs/combinations.
9. RTL languages later: a subtle "◀ read right to left" reminder under multi-character glyphs (manifest-driven; no-op for Greek).

---

## 7. Feature: Quiz (Tab 2)

### 7.1 Quiz home
- Shows: current streak (flame icon + count), longest streak, and a "Start Quiz" button.
- Filter pill bar identical in behavior/appearance to Cards view (its own selection state, defaulting to all).
- Streak displays live here and on the results sheet.

### 7.2 Question generation (`QuizEngine` — pure, unit-testable)
- 10 multiple-choice questions per quiz, 4 options each, generated from the **filtered** item pool. If the pool is too small for a type's distractor needs, skip that type; if pool < 4 items total, pull distractors from the full alphabet (never block quizzing).
- No repeated correct-answer item within one quiz (unless pool < 10).

**Question types:**

| # | Type | Prompt | Options |
|---|---|---|---|
| Q1 | Glyph → name | Show `foreignLetter`: "What is this called?" | 4 English names |
| Q2 | Name → glyph | "Which one is Omega?" | 4 glyphs |
| Q3 | Word → contains | Show a native word (from `exampleWord`): "Which letter appears in this word?" | 4 English names; exactly one option's glyph occurs in the word |
| Q4 | Name → word | "Which word contains a lambda?" | 4 native words; exactly one contains the target glyph |
| Q5 | Case match (suggested) | "Which is the lowercase form of Σ?" | 4 glyphs; only for items with `caseEquivalent`; only when `hasLetterCase` |
| Q6 | Sound → glyph (suggested) | "Which letter sounds like 'v', as in 'very'?" (from the selected system's `short` text) | 4 glyphs; only for items with a short pronunciation |

**Distractor rules (critical for fairness):**
- Distractors come from the same `itemType` and, where relevant, same case as the correct answer.
- Q3/Q4: verify no distractor word/name also satisfies the prompt (e.g. word options for "contains lambda" must not contain λ). Substring checks on lowercased/unaccented forms.
- Q6: exclude distractors sharing the same sound (Greek traps: η/ι/υ all "ee"; ο/ω both "o"). Compare short-pronunciation strings; on collision, reroll distractor.
- Q1/Q2: prefer visually or aurally confusable distractors when available (e.g. ν vs v-shape) but random-from-category is acceptable for v1.

**Adaptive weighting:** selection probability per item ∝ `1 + 3 × (1 − accuracy)` where `accuracy = timesCorrect/timesQuizzed` from `ItemProgress`; unseen items get weight 2.5. Clamp weights to [1, 4]. Weighted sampling without replacement.

### 7.3 Quiz flow & UI
- Question rendered on a **card styled like the Cards-view cards** (visual consistency). Progress "3 of 10" above.
- Options as 4 large tappable rows/tiles; selection highlights with theme accent.
- Button states: disabled "Submit" → enabled on selection → tap: lock answer, reveal result (correct option tinted green, wrong pick tinted red, brief haptic — success/error), button becomes **"Continue"** → tap: card animates off the **left** edge (same swipe animation as Cards view, auto-driven), next question card springs in from the right/stack.
- Update `ItemProgress` per answer immediately.
- Abandoning mid-quiz (leaving tab/app) keeps `QuizSession.completedAt = nil` → no streak credit; a fresh quiz starts next time (v1: no resume).

### 7.4 Results sheet
- On question 10's Continue → save session (`completedAt = .now`, score), run streak update, then present results: iPhone sheet / iPad form sheet.
- **Celebratory presentation:** animated score count-up ("8 / 10"), ring-progress fill, confetti particle burst (pure SwiftUI — `Canvas`/`TimelineView`, ~1.5s; intensity scales with score; even 10/10 gets extra flourish). Respect Reduce Motion → static presentation.
- Shows: score, per-question recap list (item glyph, right/wrong), **current streak** ("🔥 4-day streak — keep it going!"), longest streak, and whether today's streak credit was just earned.
- Buttons: "Another Quiz" (dismiss → immediately start new quiz with same filters) and "Done".

---

## 8. Theming

### 8.1 Model
```swift
struct Palette: Codable, Identifiable {
    let id: String                  // "greek-flag"
    let name: String
    let light: ThemeColors
    let dark: ThemeColors
}
struct ThemeColors: Codable {       // stored as hex strings
    let background: String          // screen background
    let surface: String             // card/sheet surfaces
    let accent: String              // pills, buttons, hero glyph
    let textPrimary: String
    let textSecondary: String
}
```
- Semantic tokens only — **no view ever hardcodes a color.** Views read `theme.accent` etc. from an `@Observable ThemeManager` in the environment.
- `ThemeManager` resolves: user custom palette → user-picked stock palette → selected language's default palette; then light/dark variant from appearance setting (`system|light|dark` via `preferredColorScheme`).
- **Language switch animates a full recolor** (wrap in `withAnimation(.easeInOut(0.4))`).

### 8.2 Palettes
- John supplies final palettes later. Ship with placeholders — `greek-flag`: light = bright blue `#0D5EAF` on white; dark = bright blue + midnight navy `#0A1A33` surfaces with white text. `russian-flag`: light = deep blue `#0033A0` accent on white with red `#DA291C` highlights; dark = navy surfaces, white text, red/blue accents. Palette definitions live in a bundled `Palettes.json` so new ones are data, not code.
- Each future language manifest names its default palette (flag-inspired).
- **Custom palette builder** (Settings): user picks accent/background/surface colors via `ColorPicker` for light and dark; stored in `UserPreferences.customPaletteData`; "Reset to language default" button.

---

## 9. Settings & Language Picker

**Language sheet** (globe/flag button, top-left): list from `LanguageRegistry`, **grouped into sections by `scriptFamily`** ("Cyrillic ▸ Russian, Ukrainian, …"); a family with one language renders as a plain row. Rows show flag emoji, display name, native name. v1 lists all nine languages (Cyrillic renders as a six-row section). Include a teaser row style ready for future entries. Selecting switches `AlphabetStore` content, filters reset to all-on, theme animates to the language default (unless user has a custom/stock override), card deck resets to first item.

**Settings sheet** (gear, top-right):
- Appearance: System / Light / Dark segmented control.
- Color scheme: stock palette list + "Custom…" builder + reset-to-default.
- Pronunciation: picker of `manifest.pronunciationSystems` display names (Greek v1: Modern only — picker present but single option; UI copy explains more coming).
- About/version footer.

Both are `.sheet` (form sheet on iPad).

---

## 10. Project setup notes for Claude Code

1. Xcode project "AlphaBeta" created in this folder (already a git repo), bundle ID `com.JohnHoedeman.AlphaBeta`, iOS 18.0 target, iPhone + iPad, portrait + landscape.
2. Capabilities: iCloud → CloudKit (container above), Background Modes → Remote notifications.
3. Copy `Manifest.json` and all nine language JSONs (in this folder, alongside this spec) into `Content/Resources/`. Do not mutate them; they are the contract.
4. `ModelContainer` with all four `@Model` types, `cloudKitDatabase: .automatic`; fall back to local-only configuration if container init throws (e.g. simulator without iCloud).
5. Provide SwiftUI Previews with an in-memory container and a `PreviewAlphabetProvider`.
6. Accessibility: Dynamic Type throughout (glyphs scale but cap), VoiceOver labels on cards ("Capital Sigma, letter, tap for details"), Reduce Motion honored (no confetti, cross-fade instead of swipe).
7. Haptics behind a small `Haptics` utility.

### Build order (milestones)
1. **M1 Content pipeline:** Codable models, manifest/registry, `BundledAlphabetProvider`, decode tests looping over **every** manifest entry (item counts per §3.1 table; spot-check Greek sigma family, Russian ъ/ь/ы, Armenian dual systems, Georgian caselessness).
2. **M2 Theming shell:** ThemeManager, placeholder palettes, RootView tabs, appearance switching.
3. **M3 Cards:** deck, swipe gestures, filter pills, shuffle, iPad constraint, card count.
4. **M4 Detail sheet:** all sections, case-sibling navigation, dismiss gestures.
5. **M5 Quiz engine:** generation + distractor rules + adaptive weighting, full unit tests.
6. **M6 Quiz UI:** question cards, submit/continue flow, auto-swipe animation.
7. **M7 Results & streaks:** StreakStore + tests, results sheet, confetti.
8. **M8 SwiftData/CloudKit:** wire persistence (in-memory until now is fine), singleton de-dup, sync smoke test.
9. **M9 Settings/Language sheets, custom palette builder, polish, accessibility pass.**

### Testing (minimum)
- `QuizEngine`: distractor validity (Q3/Q4 substring rule, Q6 sound-collision rule), no-repeat rule, small-pool degradation, weighting distribution sanity.
- `StreakStore`: all date edge cases (§4).
- JSON decoding: full round-trips of all nine bundled datasets; unknown/extra keys tolerated (forward compatibility).
- Filter logic: category mapping for all 62 items (24 caps / 25 lower / 6 diphthongs / 7 combos).

---

## 11. Future roadmap (design hooks already in place)

- **Audio:** speaker button slot in detail view + `audioProvider` protocol stub. Later: `AVSpeechSynthesizer` (per-language voice) or recorded assets referenced from manifest.
- **More pronunciation systems:** koine/ancient Greek — add `koine`/`ancient` entries to items' pronunciation maps plus the manifest's `pronunciationSystems`, and the picker lights up automatically. A `fraternity` system (letter names only) is reserved for a fun "fraternity mode" toggle. Armenian ships as one dataset with `eastern`/`western` systems.
- **New alphabets:** add `<Name>.json` + manifest entry + palette; script-family variants (Russian/Ukrainian/Serbian…, Arabic/Persian/Urdu…) are separate datasets per §3.5. Case-less scripts (`hasLetterCase: false`) auto-drop case filters/case sections; Arabic/Persian positional forms reuse leading/middle/ending fields; RTL reminder auto-enables. Devanagari/Thai may need new `itemType` values — enum decodes unknown types safely (skip + log, don't crash).
- **Remote content:** `RemoteAlphabetProvider` via CloudKit public DB, keyed by `version`.
- **IAP:** gate `LanguageRegistry` entries behind StoreKit 2 product IDs.
- **Widgets/Live Activities:** streak widget; "letter of the day."

### 11.1 Alphabet roadmap (agreed sequencing)

Phased by how much architecture each wave exercises. Nothing here requires schema changes until Phase 4.

1. **Phase 1 — drop-in (same model as Greek/Russian):** rest of Cyrillic (Ukrainian, Belarusian, Serbian, Bulgarian, Macedonian; later Kazakh, Mongolian Cyrillic), Armenian (`eastern`/`western` pronunciation systems), Georgian (first caseless language — `hasLetterCase: false`, single `letters` filter category), Coptic (niche; Greek-derived).
2. **Phase 2 — RTL wave:** Hebrew first (gentlest: five final letters ך ם ן ף ץ map onto `endingCaseEquivalent` exactly like sigma teliko; niqqud as a marked-version-style toggle later), then Arabic, Persian, Urdu (full leading/middle/ending positional forms + RTL reading reminders).
3. **Phase 3 — syllabaries (item = syllable; card model unchanged):** Japanese hiragana + katakana (two datasets, `kana` family; dakuten variants ≈ marked versions, digraphs like きゃ ≈ combinations), Korean Hangul (jamo as letters; syllable-block building as combinations — likely the highest-demand single addition), Bopomofo/Zhuyin.
4. **Phase 4 — abugidas (needs 1–2 new `itemType` values for dependent vowel signs/conjuncts):** Devanagari family (Hindi → Marathi, Nepali, Sanskrit-as-classical-system), then Bengali, Gurmukhi, Gujarati, Tamil, Telugu, Kannada, Malayalam by demand; Thai (consonant classes + tones), Lao, Khmer, Burmese, Amharic/Ge'ez.
5. **Fun packs (cheap, no flags — custom palettes):** Elder Futhark runes, Ogham, Phoenician ("ancestor of the alphabet" hook), Egyptian uniliteral hieroglyphs.

Out of scope permanently: Han characters/kanji (logographic, not an alphabet). Vertical Mongolian script is a stretch goal pending layout work.

## 12. Open items (John to supply)

1. Final color palettes (light + dark per language) — placeholder Greek palette ships meanwhile.
2. Koine/classical pronunciation data (later JSON revision).
3. Native-speaker review of the Ukrainian, Belarusian, Serbian, Bulgarian, Macedonian, Armenian, and Georgian datasets (example words, glosses, letter names) before release.
4. JSON files for additional alphabets (schema in §3 is the template; roadmap in §11.1).
5. App icon.

