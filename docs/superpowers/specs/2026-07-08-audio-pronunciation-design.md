# Audio pronunciation (letter name + example word)

Status: approved, not yet implemented.

## Motivation

SPEC §11 already reserves a speaker-button slot in the Item Detail sheet
("audio designed-for, not shipped"). This design fills that hook in for
real, with one constraint driving every decision: **accuracy over
coverage**. Generic TTS is worst exactly where this app needs it most —
letter names (invented/rare words no TTS engine has trained on) and
historical or liturgical pronunciation systems (Bohairic Coptic, a future
Koine Greek) that no synthesized voice can represent at all, because they
model one modern standard per language, not a specific era or tradition.

Decision: use TTS only where it can be trusted; leave audio out entirely
where it can't; scaffold the interface so real recordings can replace or
supplement TTS later without UI changes.

## Scope

- Content voiced: the item's **letter name** (`foreignLetterName`, e.g.
  "βήτα") and its **example word** (`parsedExampleWord.word`). Not the
  isolated phoneme/sound, not the explanation text.
- Surface: **Item Detail sheet only** for this pass. Cards view and Quiz
  get no audio button now — a later pass can add it if wanted.
- Out of scope (deliberately not built now): recorded-audio assets
  themselves, a recording/upload pipeline, remote audio delivery. Only the
  interface boundary that would let a recorded-audio provider drop in
  later.

## Architecture

### `AudioSpeaking` protocol + `SpeechRequest`

```swift
enum AudioField { case letterName, exampleWord }

struct SpeechRequest {
    let itemIdentifier: Int
    let field: AudioField
    let text: String              // native-script text to synthesize
    let localeIdentifier: String  // BCP-47, e.g. "el-GR"
}

protocol AudioSpeaking {
    func speak(_ request: SpeechRequest)
    func stop()
}
```

`SpeechRequest` carries `itemIdentifier` + `field`, not just raw text, so a
future `RecordedAudioSpeaker: AudioSpeaking` can look up a bundled/remote
audio file keyed by `(languageID, itemIdentifier, field)` and fall back to
`text` + `localeIdentifier` TTS only when no recording exists yet.
Swapping or blending providers needs no UI changes.

Only one concrete implementation ships now: `SystemVoiceAudioSpeaker`, a
thin wrapper around `AVSpeechSynthesizer`. If
`AVSpeechSynthesisVoice(language:)` can't resolve the requested locale at
all, it silently no-ops rather than falling back to a wrong-language
voice — defense in depth, since the button shouldn't have been shown in
that case anyway.

### Pure availability resolver

A pure, fully unit-testable function decides *whether* a speaker button
should even appear — no `AVFoundation` involved, same "pure core, thin
impure edge" split as `QuizEngine`:

```swift
extension AlphabetItem {
    func speechRequest(
        field: AudioField,
        pronunciationSystems: [PronunciationSystem],
        systemID: String
    ) -> SpeechRequest? {
        guard let locale = pronunciationSystems.first(where: { $0.id == systemID })?.ttsLocale else {
            return nil
        }
        switch field {
        case .letterName:
            guard let name = foreignLetterName else { return nil }
            return SpeechRequest(itemIdentifier: identifier, field: field, text: name, localeIdentifier: locale)
        case .exampleWord:
            guard let word = parsedExampleWord?.word else { return nil }
            return SpeechRequest(itemIdentifier: identifier, field: field, text: word, localeIdentifier: locale)
        }
    }
}
```

## Accuracy gating: `ttsLocale` on `PronunciationSystem`

The dialect/era concern (Bohairic Coptic, Koine vs. Modern Greek, Eastern
vs. Western Armenian) already lives at the *pronunciation-system* level in
the schema — so audio gating belongs there too, not at the language level:

```swift
struct PronunciationSystem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let ttsLocale: String?   // nil = no accurate voice exists; audio UI stays hidden
}
```

- `modern` Greek → a real `el-GR` locale — iOS's Greek voice speaks exactly
  this standard.
- `bohairic` Coptic → **always `nil`**. Not a "voice pack missing" gap —
  no TTS engine has ever modeled Bohairic liturgical pronunciation, and
  none plausibly will. The same reasoning applies to any future `koine`
  Greek system.
- Armenian `eastern`/`western`, Belarusian, Macedonian, Georgian → not
  assumed here. Verify against actual `AVSpeechSynthesisVoice.speechVoices()`
  output on the target OS version before assigning `ttsLocale`, since
  voice coverage changes across iOS releases and a voice existing for
  "Armenian" likely models only one of the two standards. Where a voice
  exists but there's real doubt about which regional/historical standard
  it represents, default to `nil` and flag it for review rather than
  guess.

## UI: two speaker buttons in `ItemDetailSheet`

The existing hidden speaker slot lives in `pronunciationSection`'s header
— it's retired, since it doesn't match "letter name + example word" as the
content being voiced. Two purpose-built buttons replace it:

- Next to `foreignLetterName` in `heroSection` → speaks the letter name.
  Hidden when `speechRequest(field: .letterName, ...)` resolves to `nil`.
- Next to the word in `exampleWordSection` → speaks the example word.
  Hidden when that resolves to `nil`.

Both are small `speaker.wave.2.fill` icon buttons with
`.accessibilityLabel("Play pronunciation")`, consistent with the
accessibility pass done in M9. Tapping calls `audioSpeaking.stop()` then
`speak(request)`, so rapid taps between the two buttons (or a case-form
swap mid-utterance) never overlap audio.

`ItemDetailSheet` gains an `audioSpeaking: AudioSpeaking` dependency,
injected the same way `pronunciationSystemID` already is, defaulting to
`SystemVoiceAudioSpeaker()`.

## Testing

- Pure resolver tests (no `AVFoundation`) for `speechRequest(field:pronunciationSystems:systemID:)`:
  - `nil` when the active system's `ttsLocale` is `nil`.
  - `nil` when the field's own text is `nil` (no `foreignLetterName`, or no
    example word).
  - Correct locale + text returned when both are present.
  - Falls through correctly when the requested `systemID` isn't found,
    mirroring `pronunciation(preferring:)`'s existing fallback behavior.
- `SystemVoiceAudioSpeaker` itself is not unit tested — a thin
  `AVFoundation` boundary, same treatment as other OS-boundary code in
  this project. Verified manually in Simulator instead.
- Manual Simulator check: tap a letter in a `ttsLocale`-enabled language
  and confirm it actually speaks correctly; confirm the button is *absent*
  for Coptic and any other `nil`-gated system.

## SPEC.md updates required

1. §3.4 — add `ttsLocale: String?` to `PronunciationSystem`'s schema.
2. §11 — rewrite the "Audio:" bullet from a design hook to what's
   actually shipped (`AudioSpeaking` protocol, `SystemVoiceAudioSpeaker`,
   per-system `ttsLocale` gating), and name the future recorded-audio path
   as the intended next step for the `RecordedAudioSpeaker` slot.
3. §12 Open Items — add an entry listing exactly which languages/systems
   shipped with `ttsLocale` set vs. `nil` and why, so the choices can be
   reviewed/corrected — the same transparency treatment Coptic's content
   got.
