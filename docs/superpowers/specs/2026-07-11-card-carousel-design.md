# Cards tab: paged carousel instead of swipe-to-dismiss deck

Status: approved, not yet implemented.

## Motivation

User feedback: the current `CardDeckView` swipe-to-dismiss gesture reads as a
Tinder-style yes/no judgment on each letter, which isn't the intent — there's
no "reject" semantic for an alphabet flashcard. Separately, changing a filter
pill mid-browse currently loses your place (`CardDeckViewModel` resets to the
front of the filtered set), which is disorienting.

Reference paradigm: a third-party car-listing app's asset browser — a
horizontally-paged carousel where one item is centered and focused, with the
previous/next items peeking in at the edges, dimmed and slightly scaled down.
Swiping pages between items; nothing is discarded or judged. Tapping the
focused item opens its detail page.

This design replaces the Cards tab's navigation model with that paradigm.
`ItemDetailSheet` itself (opened by tapping the focused card) is unchanged —
this is purely a Cards-tab navigation change.

## Scope

- In scope: `CardDeckView` → a new paged/peeking carousel; `CardDeckViewModel`
  navigation semantics (focus index, filter-fallback, shuffle-reset, wrap).
- Out of scope: `ItemDetailSheet` content/behavior, Quiz tab, `FilterPillBar`'s
  own layout (already centered on iPad per the earlier centering fix) — only
  its *effect* on carousel focus changes.

## Navigation model (`CardDeckViewModel`)

Today, `currentIndex` means "top of stack, about to be swiped away and
discarded." It becomes "index of the currently focused card" — a pure
position that persists across swipes, taps, filters, and shuffles rather than
being consumed:

- **Swiping** moves focus by ±1 card, with standard iOS scroll-paging
  physics (follows the finger 1:1 while dragging, animated snap to the
  nearest card on release).
- **Tapping a peeking neighbor card** animates focus directly to that card
  (`scrollPosition.scrollTo(id:)`).
- **Tapping the focused (center) card** opens `ItemDetailSheet`, unchanged
  from today.
- **Filter change:** if the focused item still passes the new filter, stay
  on it (re-resolve its index within the newly filtered array). If it no
  longer passes, walk forward through the *original, unfiltered* alphabet
  order starting from the focused item's old position, and focus the first
  item encountered that passes the new filter. This jump is a pure,
  unit-testable function and snaps instantly — no animated travel through
  intervening cards (deliberately different from a user-driven swipe, since
  the distance could be arbitrarily large and an animated fast-scroll would
  read as jarring rather than informative).
- **Shuffle toggle:** reshuffles the order and resets focus to index 0 of
  the new shuffled sequence.
- **Wrap-around:** swiping forward past the last card moves focus to index
  0; swiping backward past index 0 moves focus to the last card. Both
  directions show the wrap indicator (below).

## UI implementation approach

Built on iOS 17's `ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)`
+ `.scrollPosition(id:)` — the SwiftUI-native paged/peeking carousel
primitive — rather than a hand-rolled `DragGesture`. Each card's width is
narrower than the screen, which is what produces the peek automatically. The
`scrollPosition` binding is bidirectional: it reflects the user's own swipes
back into `CardDeckViewModel`, and the view model drives it programmatically
for neighbor-taps, filter-forced jumps, and shuffle resets.

Non-focused cards are dimmed and scaled down via `.scrollTransition`, which
SwiftUI drives continuously as the user drags — neighbors visibly brighten
and grow as they approach center, rather than snapping between two fixed
visual states.

The existing `"\(currentIndex + 1) / \(count)"` position text below the deck
is retained unchanged.

## iPad sizing

The focused card keeps the same absolute size it has on iPhone (matching
today's 480×640-constrained deck), rather than growing to fill iPad's wider
screen. The extra width becomes additional horizontal padding around the
scroll content, which reveals more of each neighbor at the edges — a larger
peek "for free," with no separate iPad-specific peek-width calculation.

## Wrap-around mechanics

`ScrollView` won't natively let you swipe "past" the last real card, since
there's no content beyond it to drag into. Implementation approach: pad the
rendered data source with sentinel duplicates — `[lastItem, item1, item2,
..., itemN, firstItem]` — so swiping past `itemN` lands on the `firstItem`
duplicate. The instant it settles there, `CardDeckViewModel` silently
re-points `scrollPosition` to the *real* `firstItem`'s id with no animation
(visually imperceptible, since the duplicate is identical content), and that
re-point is the trigger for showing the wrap indicator. The same trick
mirrors at the start for backward wrap. This is the trickiest single piece of
the implementation but is a well-established SwiftUI/UIKit carousel pattern,
not a novel risk.

**Wrap indicator:** an iOS-native-feeling capsule — `.ultraThinMaterial`
background, an SF Symbol (e.g. `arrow.uturn.backward`) plus short text ("Back
to the beginning") — slides down from the top-center and auto-dismisses
after ~1.5s, paired with `Haptics.selection()`. Modeled on the system
"Copied" / AirDrop-confirmation style, not an Android-style bottom toast.

## Peek sizing (from visual review)

- iPhone: moderate peek, ~20% of each neighbor card visible — enough to
  signal "there's more" without competing with the focused card.
- iPad: same absolute focused-card size as iPhone; the extra width just
  exposes more of each neighbor (larger peek than iPhone's ~20%, but not a
  separate deliberately-chosen ratio — it falls out of the fixed card size).

## Testing

Following this project's existing "pure core, thin impure edge" split (same
treatment as `QuizEngine`/the current `CardDeckViewModel`):

- Pure, unit-tested: the filter-fallback resolver (stay-if-still-visible /
  else-walk-forward-in-original-order), the shuffle-reset-to-index-0
  behavior, and the wrap index math (including the sentinel-to-real
  re-pointing logic).
- Not unit tested: the `ScrollView` / `scrollTargetBehavior` / `.scrollTransition`
  wiring itself — same treatment as other pure-SwiftUI-layout code in this
  project. Verified manually in Simulator: swipe forward/back, tap a
  neighbor, tap a filter mid-browse (both the stay-put and jump-forward
  cases), toggle shuffle, wrap in both directions, and confirm the wrap
  indicator appears and auto-dismisses.

## SPEC.md updates required

1. §5 (Cards tab) — replace the swipe-to-dismiss deck description with the
   paged carousel description (peek amount, tap-to-focus-neighbor,
   tap-focused-to-open-detail, wrap-around, wrap indicator).
2. §5 (iPad) — note the fixed-card-size/more-peek iPad behavior, alongside
   the already-implemented centered `FilterPillBar`.
3. Any milestone-numbered section that references `CardDeckView`/swipe
   gesture behavior by name should be updated to reference the carousel
   instead, once implemented.
