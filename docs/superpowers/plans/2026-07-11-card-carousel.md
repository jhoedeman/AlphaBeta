# Cards Tab Paged Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Cards tab's swipe-to-dismiss card deck with a horizontally-paged, peeking carousel where nothing is discarded, per `docs/superpowers/specs/2026-07-11-card-carousel-design.md`.

**Architecture:** `CardDeckViewModel` keeps its existing filter/shuffle/order state but changes `currentIndex` from "top of a stack about to be discarded" to "index of the focused card," adding pure, unit-tested logic for filter-fallback resolution, shuffle-reset, and wrap detection. A new `CardCarouselView` renders every item in a `ScrollView(.horizontal)` with `.scrollTargetBehavior(.viewAligned)` and `.scrollPosition(id:)`, using two sentinel duplicate entries (of the last/first real item) to make "swipe past the end" detectable, then silently re-points to the real item and shows a native-style wrap indicator.

**Tech Stack:** Swift 5, SwiftUI (iOS 18 deployment target — `scrollTargetBehavior`/`scrollPosition`/`.scrollTransition` are iOS 17+ APIs, no availability guards needed), Swift Testing (`@Test`/`#expect`), `@Observable` macro, xcodegen for project file generation.

## Global Constraints

- Deployment target is iOS 18 (`project.yml`) — no `@available` guards needed for any SwiftUI API used here.
- `CardDeckViewModel` must stay free of `import SwiftUI` (existing file doc comment: "Kept free of SwiftUI so it's unit-testable independent of gestures/animation") — all animation/`Transaction` decisions live in the view layer, not the view model.
- Regenerate the Xcode project with `~/bin/xcodegen_dist/bin/xcodegen` (the real binary), **not** the `xcodegen` symlink on `PATH` — the symlinked version has previously silently failed to pick up new file references in this project.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), matching every existing test file in `AlphaBetaTests/` — not XCTest.
- New/changed pure-logic code goes in `CardDeckViewModel`; new/changed SwiftUI view code is not unit tested, matching this project's established "pure core, thin impure edge" split (same treatment as `QuizEngine` and every other feature's view layer) — verified manually in Simulator instead.
- Simulator UDIDs for manual verification: iPhone 16 Pro `41E3CEAB-05B3-4186-83D7-926F525AA8E9`, iPad Pro 11-inch (M4) `08B50418-A893-4125-94C9-119B6CAEDCDE`. Scheme: `AlphaBeta`, project: `AlphaBeta.xcodeproj`.

---

## File Structure

- **Modify:** `Features/Cards/CardDeckViewModel.swift` — carousel entry shaping (with sentinels), wrap detection, neighbor-focus, filter-fallback resolution, shuffle-reset. Removes `advance()`, `retreat()`, `peekItems(_:)` (superseded — the carousel view renders every entry directly and lets `ScrollView` handle paging).
- **Modify:** `AlphaBetaTests/CardDeckViewModelTests.swift` — removes tests for deleted methods, adds tests for the new carousel/wrap/filter-fallback/shuffle-reset behavior.
- **Create:** `Features/Cards/WrapIndicatorView.swift` — the native-style top-center capsule shown on wrap.
- **Create:** `Features/Cards/CardCarouselView.swift` — the paged/peeking carousel, replacing `CardDeckView`.
- **Delete:** `Features/Cards/CardDeckView.swift` — the old swipe-to-dismiss stack.
- **Modify:** `Features/Cards/CardsView.swift` — swap `CardDeckView` for `CardCarouselView`, drop the now-unused `reduceMotion` plumbing (the carousel reads it itself) and the `480×640` container constraint (the carousel needs the full available width so iPad's extra width becomes peek, per the design doc's iPad-sizing section).
- **Modify:** `SPEC.md` — §5 Cards tab description and iPad note, updated to describe the shipped carousel instead of the swipe deck.
- `Features/Cards/CardFaceView.swift` is reused unchanged — it's already pure presentation of one item, independent of the deck/carousel's navigation model.

---

### Task 1: `CardDeckViewModel` — carousel entries with sentinels

**Files:**
- Modify: `Features/Cards/CardDeckViewModel.swift`
- Test: `AlphaBetaTests/CardDeckViewModelTests.swift`

**Interfaces:**
- Produces: `CardDeckViewModel.CarouselEntry` (`Identifiable, Hashable`, with `id: String` and `item: AlphabetItem`), `var carouselEntries: [CarouselEntry]`, `func entryID(at index: Int) -> String?`. Later tasks (2, 3) and the new `CardCarouselView` (Task 5) consume all three.

- [ ] **Step 1: Write the failing tests**

Add to `AlphaBetaTests/CardDeckViewModelTests.swift`, in a new `// MARK: - Carousel entries (sentinels)` section at the end of the `struct`:

```swift
    // MARK: - Carousel entries (sentinels)

    @Test func carouselEntriesWrapsRealItemsWithLeadingAndTrailingSentinels() {
        let viewModel = makeViewModel()
        let entries = viewModel.carouselEntries
        #expect(entries.count == Self.items.count + 2)
        #expect(entries.first?.id == "sentinel-leading")
        #expect(entries.first?.item.id == Self.diphthong.id) // mirrors the last real item
        #expect(entries.last?.id == "sentinel-trailing")
        #expect(entries.last?.item.id == Self.capitalA.id) // mirrors the first real item
        #expect(entries[1].id == "real-\(Self.capitalA.identifier)")
        #expect(entries[2].id == "real-\(Self.lowerA.identifier)")
        #expect(entries[3].id == "real-\(Self.diphthong.identifier)")
    }

    @Test func carouselEntriesIsEmptyWhenDeckIsEmpty() {
        let viewModel = makeViewModel()
        for category in Self.manifest.filterCategories {
            viewModel.toggleFilter(category)
        }
        #expect(viewModel.carouselEntries.isEmpty)
    }

    @Test func entryIDReturnsRealPrefixedIdentifierForValidIndex() {
        let viewModel = makeViewModel()
        #expect(viewModel.entryID(at: 0) == "real-\(Self.capitalA.identifier)")
        #expect(viewModel.entryID(at: 2) == "real-\(Self.diphthong.identifier)")
    }

    @Test func entryIDReturnsNilForOutOfBoundsIndex() {
        let viewModel = makeViewModel()
        #expect(viewModel.entryID(at: -1) == nil)
        #expect(viewModel.entryID(at: 99) == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' -only-testing:AlphaBetaTests/CardDeckViewModelTests 2>&1 | tail -40`
Expected: FAIL to build — `carouselEntries`, `entryID(at:)`, and `CarouselEntry` don't exist yet.

- [ ] **Step 3: Add `CarouselEntry`, `carouselEntries`, and `entryID(at:)`**

In `Features/Cards/CardDeckViewModel.swift`, add after the `currentIndex` property declaration (after line 19, before `init`):

```swift

    /// One rendered slot in the carousel. `id` disambiguates a real item's
    /// own card from a sentinel duplicate used to detect wraparound — see
    /// `carouselEntries`.
    struct CarouselEntry: Identifiable, Hashable {
        let id: String
        let item: AlphabetItem
    }
```

Then add these computed members after the existing `currentItem` computed property (after line 38):

```swift

    /// The carousel's full rendered sequence: every item in `order`, padded
    /// with a leading sentinel that duplicates the last item and a trailing
    /// sentinel that duplicates the first. `CardCarouselView` pages through
    /// this array with `ScrollView`/`scrollTargetBehavior(.viewAligned)`;
    /// landing on a sentinel is how it detects "the user swiped past the
    /// real end," since `ScrollView` has no content beyond the real items to
    /// drag into otherwise.
    var carouselEntries: [CarouselEntry] {
        guard !order.isEmpty else { return [] }
        var entries = order.map { CarouselEntry(id: "real-\($0.identifier)", item: $0) }
        entries.insert(CarouselEntry(id: "sentinel-leading", item: order.last!), at: 0)
        entries.append(CarouselEntry(id: "sentinel-trailing", item: order.first!))
        return entries
    }

    /// The carousel entry id for a real item at `index` in `order`, or `nil`
    /// if `index` is out of bounds (e.g. an empty deck).
    func entryID(at index: Int) -> String? {
        guard order.indices.contains(index) else { return nil }
        return "real-\(order[index].identifier)"
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' -only-testing:AlphaBetaTests/CardDeckViewModelTests 2>&1 | tail -40`
Expected: PASS — all `CardDeckViewModelTests` tests pass, including the four new ones.

- [ ] **Step 5: Commit**

```bash
git add Features/Cards/CardDeckViewModel.swift AlphaBetaTests/CardDeckViewModelTests.swift
git commit -m "Add carousel entry shaping with wraparound sentinels to CardDeckViewModel"
```

---

### Task 2: `CardDeckViewModel` — wrap detection and neighbor-tap focus, remove `advance`/`retreat`/`peekItems`

**Files:**
- Modify: `Features/Cards/CardDeckViewModel.swift`
- Test: `AlphaBetaTests/CardDeckViewModelTests.swift`

**Interfaces:**
- Consumes: `CarouselEntry`, `entryID(at:)` from Task 1.
- Produces: `CardDeckViewModel.WrapEvent` (`enum, Equatable`: `.forward`, `.backward`), `var wrapEvent: WrapEvent?`, `var lastIndexChangeAnimates: Bool`, `func handleScrollSettled(to id: String?)`, `func focusNeighbor(_ item: AlphabetItem)`, `func clearWrapEvent()`. Task 5's `CardCarouselView` consumes all of these; Task 3 also sets `lastIndexChangeAnimates`.

- [ ] **Step 1: Write the failing tests**

First, remove these four now-obsolete tests from `AlphaBetaTests/CardDeckViewModelTests.swift` (they test methods this task deletes):

```swift
    @Test func advanceWrapsAroundToStart() {
        let viewModel = makeViewModel()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.currentItem?.id == Self.diphthong.id)
        viewModel.advance()
        #expect(viewModel.currentItem?.id == Self.capitalA.id)
    }

    @Test func retreatWrapsAroundToEnd() {
        let viewModel = makeViewModel()
        viewModel.retreat()
        #expect(viewModel.currentItem?.id == Self.diphthong.id)
    }
```

```swift
    @Test func peekItemsWrapsAndCapsAtDeckSizeMinusOne() {
        let viewModel = makeViewModel()
        let peeks = viewModel.peekItems(2)
        #expect(peeks.map(\.id) == [Self.lowerA.id, Self.diphthong.id])

        viewModel.advance()
        viewModel.advance()
        let wrapped = viewModel.peekItems(2)
        #expect(wrapped.map(\.id) == [Self.capitalA.id, Self.lowerA.id])
    }

    @Test func peekItemsCapsAtDeckSizeMinusOneWhenSmall() {
        let viewModel = makeViewModel()
        viewModel.toggleFilter(.diphthongs)
        #expect(viewModel.count == 2)
        #expect(viewModel.peekItems(2).map(\.id) == [Self.lowerA.id])
    }
```

`hideNamesDefaultsToFalseAndTogglesWithoutAffectingDeckState` also calls `viewModel.advance()` — replace that one call so the test still moves focus without the deleted method:

```swift
    @Test func hideNamesDefaultsToFalseAndTogglesWithoutAffectingDeckState() {
        let viewModel = makeViewModel()
        #expect(viewModel.hideNames == false)

        viewModel.focusNeighbor(Self.lowerA)
        viewModel.toggleHideNames()
        #expect(viewModel.hideNames == true)
        #expect(viewModel.currentIndex == 1)

        viewModel.toggleHideNames()
        #expect(viewModel.hideNames == false)
    }
```

Now add new tests in the `// MARK: - Carousel entries (sentinels)` section (rename it to `// MARK: - Carousel entries, wrap, and neighbor focus` since it now covers more):

```swift
    @Test func focusNeighborUpdatesCurrentIndexAndMarksTheChangeAsAnimated() {
        let viewModel = makeViewModel()
        viewModel.lastIndexChangeAnimates = false // prove focusNeighbor flips it back to true
        viewModel.focusNeighbor(Self.diphthong)
        #expect(viewModel.currentIndex == 2)
        #expect(viewModel.currentItem?.id == Self.diphthong.id)
        #expect(viewModel.lastIndexChangeAnimates == true)
    }

    @Test func focusNeighborIgnoresAnItemNotInTheCurrentOrder() {
        let viewModel = makeViewModel()
        viewModel.toggleFilter(.diphthongs) // removes Self.diphthong from `order`
        viewModel.focusNeighbor(Self.diphthong)
        #expect(viewModel.currentIndex == 0) // unchanged — no matching item to focus
    }

    @Test func handleScrollSettledOnTrailingSentinelWrapsForwardToStart() {
        let viewModel = makeViewModel()
        viewModel.focusNeighbor(Self.diphthong)
        viewModel.handleScrollSettled(to: "sentinel-trailing")
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.currentItem?.id == Self.capitalA.id)
        #expect(viewModel.wrapEvent == .forward)
        #expect(viewModel.lastIndexChangeAnimates == false)
    }

    @Test func handleScrollSettledOnLeadingSentinelWrapsBackwardToEnd() {
        let viewModel = makeViewModel()
        viewModel.handleScrollSettled(to: "sentinel-leading")
        #expect(viewModel.currentIndex == Self.items.count - 1)
        #expect(viewModel.currentItem?.id == Self.diphthong.id)
        #expect(viewModel.wrapEvent == .backward)
        #expect(viewModel.lastIndexChangeAnimates == false)
    }

    @Test func handleScrollSettledOnARealEntryUpdatesCurrentIndexOnly() {
        let viewModel = makeViewModel()
        viewModel.handleScrollSettled(to: "real-\(Self.diphthong.identifier)")
        #expect(viewModel.currentIndex == 2)
        #expect(viewModel.wrapEvent == nil)
    }

    @Test func handleScrollSettledIgnoresAnUnrecognizedID() {
        let viewModel = makeViewModel()
        viewModel.handleScrollSettled(to: "not-a-real-id")
        #expect(viewModel.currentIndex == 0)
    }

    @Test func clearWrapEventResetsToNil() {
        let viewModel = makeViewModel()
        viewModel.handleScrollSettled(to: "sentinel-leading")
        #expect(viewModel.wrapEvent != nil)
        viewModel.clearWrapEvent()
        #expect(viewModel.wrapEvent == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' -only-testing:AlphaBetaTests/CardDeckViewModelTests 2>&1 | tail -60`
Expected: FAIL to build — `WrapEvent`, `wrapEvent`, `lastIndexChangeAnimates`, `handleScrollSettled(to:)`, `focusNeighbor(_:)`, and `clearWrapEvent()` don't exist yet; `advance()`/`retreat()`/`peekItems(_:)` calls in the tests you just deleted are gone, but the source methods still exist (fine — deleted in Step 3).

- [ ] **Step 3: Implement wrap detection and neighbor focus; delete `advance`/`retreat`/`peekItems`**

In `Features/Cards/CardDeckViewModel.swift`, delete these three methods entirely:

```swift
    func advance() {
        guard count > 0 else { return }
        currentIndex = (currentIndex + 1) % count
    }

    func retreat() {
        guard count > 0 else { return }
        currentIndex = (currentIndex - 1 + count) % count
    }

    /// The next `n` items after the current one, for the peeking stack —
    /// wraps around, and returns fewer than `n` if the deck is that small.
    func peekItems(_ n: Int) -> [AlphabetItem] {
        guard count > 1 else { return [] }
        return (1...min(n, count - 1)).map { order[(currentIndex + $0) % count] }
    }
```

Add two new stored properties right after `private(set) var currentIndex = 0`:

```swift
    /// Set by wrap detection so `CardCarouselView` can show the wrap
    /// indicator; cleared via `clearWrapEvent()` once the indicator's
    /// auto-dismiss timer fires.
    private(set) var wrapEvent: WrapEvent?
    /// Whether the *next* `currentIndex` change the view observes should
    /// animate its scroll position, or snap instantly. Filter/shuffle
    /// changes and wrap re-pointing set this `false`; `focusNeighbor` sets
    /// it back to `true`. Read once per change by the view's
    /// `onChange(of: currentIndex)` handler.
    var lastIndexChangeAnimates = true
```

Add the `WrapEvent` enum near `CarouselEntry` (both are small supporting types — keep them together, right after `CarouselEntry`'s closing brace):

```swift

    enum WrapEvent: Equatable {
        case forward
        case backward
    }
```

Add these three methods after `entryID(at:)`:

```swift

    /// Called by the view whenever its scroll position settles on a new
    /// entry id — including the two sentinels. A sentinel means the user
    /// swiped past the real end of the deck; this re-points `currentIndex`
    /// to the matching real end and raises `wrapEvent` so the view can show
    /// the wrap indicator, without animating the (imperceptible) snap back
    /// to the real item's own id.
    func handleScrollSettled(to id: String?) {
        guard let id, !order.isEmpty else { return }
        switch id {
        case "sentinel-trailing":
            currentIndex = 0
            lastIndexChangeAnimates = false
            wrapEvent = .forward
        case "sentinel-leading":
            currentIndex = order.count - 1
            lastIndexChangeAnimates = false
            wrapEvent = .backward
        default:
            if let identifier = Self.itemIdentifier(fromEntryID: id),
               let index = order.firstIndex(where: { $0.identifier == identifier }) {
                currentIndex = index
            }
        }
    }

    /// Tapping a peeking neighbor card brings it into focus with an
    /// animated scroll, unlike a filter/shuffle-forced jump.
    func focusNeighbor(_ item: AlphabetItem) {
        guard let index = order.firstIndex(where: { $0.id == item.id }) else { return }
        currentIndex = index
        lastIndexChangeAnimates = true
    }

    func clearWrapEvent() {
        wrapEvent = nil
    }

    private static func itemIdentifier(fromEntryID id: String) -> Int? {
        guard id.hasPrefix("real-") else { return nil }
        return Int(id.dropFirst("real-".count))
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' -only-testing:AlphaBetaTests/CardDeckViewModelTests 2>&1 | tail -60`
Expected: PASS — every `CardDeckViewModelTests` test passes, including the new ones and the rewritten `hideNamesDefaultsToFalseAndTogglesWithoutAffectingDeckState`.

- [ ] **Step 5: Commit**

```bash
git add Features/Cards/CardDeckViewModel.swift AlphaBetaTests/CardDeckViewModelTests.swift
git commit -m "Add wrap detection and neighbor-tap focus to CardDeckViewModel; remove swipe-deck advance/retreat/peekItems"
```

---

### Task 3: `CardDeckViewModel` — filter fallback and shuffle-reset, replacing `refreshOrder`

**Files:**
- Modify: `Features/Cards/CardDeckViewModel.swift`
- Test: `AlphaBetaTests/CardDeckViewModelTests.swift`

**Interfaces:**
- Consumes: `lastIndexChangeAnimates` from Task 2.
- Produces: `CardDeckViewModel.resolveFocusIndex(previousFocusedItem:allItemsInOriginalOrder:newOrder:) -> Int` (static, pure — testable in isolation); rewired `toggleFilter` (stays on the focused item, or walks forward to the next visible one) and `toggleShuffle` (always resets focus to index `0`) sharing a new private `recomputeOrder() -> [AlphabetItem]` helper.

This task replaces `toggleFilter` and `toggleShuffle` together, in one pass — both call the same `refreshOrder()` method today, and splitting their replacement across two tasks would leave the view model unable to build in between (`toggleShuffle` still calling a deleted method). One task, one buildable-and-tested deliverable, per this plan's "each task ends with an independently testable deliverable" rule.

- [ ] **Step 1: Write the failing tests**

Replace the existing `filterChangeResetsCurrentIndex` test (its assumption — that any filter change resets to index 0 — is exactly what this task changes) with:

```swift
    @Test func filterChangeKeepsFocusOnTheSameItemWhenItIsStillVisible() {
        let viewModel = makeViewModel()
        viewModel.focusNeighbor(Self.lowerA)
        viewModel.toggleFilter(.diphthongs) // lowerA still passes capitals+lowercase
        #expect(viewModel.currentItem?.id == Self.lowerA.id)
    }

    @Test func filterChangeWalksForwardInOriginalOrderWhenFocusedItemIsFilteredOut() {
        let viewModel = makeViewModel()
        viewModel.focusNeighbor(Self.lowerA)
        viewModel.toggleFilter(.lowercase) // removes lowerA; diphthong is next in original order
        #expect(viewModel.currentItem?.id == Self.diphthong.id)
    }

    @Test func filterChangeWrapsSearchToTheStartWhenNothingLaterIsVisible() {
        let viewModel = makeViewModel()
        viewModel.focusNeighbor(Self.diphthong) // last item in original order
        viewModel.toggleFilter(.diphthongs) // removes diphthong; nothing after it survives either
        #expect(viewModel.currentItem?.id == Self.capitalA.id) // wraps the search back to the start
    }

    @Test func filterChangeToEmptyDeckLeavesCurrentItemNil() {
        let viewModel = makeViewModel()
        for category in Self.manifest.filterCategories {
            viewModel.toggleFilter(category)
        }
        #expect(viewModel.currentItem == nil)
        #expect(viewModel.currentIndex == 0)
    }

    // MARK: - resolveFocusIndex (pure function)

    @Test func resolveFocusIndexReturnsZeroWhenThereWasNoPreviousFocus() {
        let index = CardDeckViewModel.resolveFocusIndex(
            previousFocusedItem: nil, allItemsInOriginalOrder: Self.items, newOrder: Self.items
        )
        #expect(index == 0)
    }

    @Test func resolveFocusIndexFindsTheSameItemInTheNewOrderRegardlessOfPosition() {
        let reordered = [Self.diphthong, Self.capitalA, Self.lowerA]
        let index = CardDeckViewModel.resolveFocusIndex(
            previousFocusedItem: Self.lowerA, allItemsInOriginalOrder: Self.items, newOrder: reordered
        )
        #expect(index == 2)
    }

    @Test func resolveFocusIndexWalksForwardThroughOriginalOrderWhenItemIsMissing() {
        let newOrder = [Self.capitalA] // lowerA and diphthong both filtered out
        let index = CardDeckViewModel.resolveFocusIndex(
            previousFocusedItem: Self.lowerA, allItemsInOriginalOrder: Self.items, newOrder: newOrder
        )
        #expect(index == 0) // capitalA is the only survivor
    }

    @Test func resolveFocusIndexReturnsZeroWhenNewOrderIsEmpty() {
        let index = CardDeckViewModel.resolveFocusIndex(
            previousFocusedItem: Self.lowerA, allItemsInOriginalOrder: Self.items, newOrder: []
        )
        #expect(index == 0)
    }

    @Test func shuffleToggleResetsFocusToTheFirstShuffledItem() {
        let viewModel = makeViewModel()
        viewModel.focusNeighbor(Self.diphthong)
        viewModel.toggleShuffle()
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.currentItem?.id == viewModel.order.first?.id)
        #expect(viewModel.lastIndexChangeAnimates == false)

        viewModel.focusNeighbor(viewModel.order[1])
        viewModel.toggleShuffle() // toggling off restores manifest order, still resets to 0
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.currentItem?.id == Self.capitalA.id)
    }
```

Delete the old test being replaced:

```swift
    @Test func filterChangeResetsCurrentIndex() {
        let viewModel = makeViewModel()
        viewModel.advance()
        #expect(viewModel.currentIndex == 1)
        viewModel.toggleFilter(.diphthongs)
        #expect(viewModel.currentIndex == 0)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' -only-testing:AlphaBetaTests/CardDeckViewModelTests 2>&1 | tail -60`
Expected: FAIL to build — `resolveFocusIndex` doesn't exist yet, and `advance()` (used in the not-yet-deleted old test) no longer exists either since Task 2 removed it.

- [ ] **Step 3: Implement `resolveFocusIndex`, and rewire `toggleFilter`/`toggleShuffle`**

In `Features/Cards/CardDeckViewModel.swift`, replace the existing `refreshOrder` method and its call sites. First, replace:

```swift
    func toggleFilter(_ category: FilterCategory) {
        if selectedFilters.contains(category) {
            selectedFilters.remove(category)
        } else {
            selectedFilters.insert(category)
        }
        refreshOrder()
        notifyPreferencesChanged()
    }
```

with:

```swift
    func toggleFilter(_ category: FilterCategory) {
        if selectedFilters.contains(category) {
            selectedFilters.remove(category)
        } else {
            selectedFilters.insert(category)
        }
        let previousFocusedItem = currentItem
        order = recomputeOrder()
        currentIndex = Self.resolveFocusIndex(
            previousFocusedItem: previousFocusedItem, allItemsInOriginalOrder: allItems, newOrder: order
        )
        lastIndexChangeAnimates = false
        notifyPreferencesChanged()
    }
```

Then replace the `private func refreshOrder()` method:

```swift
    private func refreshOrder() {
        var next = Self.filteredOrder(allItems: allItems, manifest: manifest, filters: selectedFilters)
        if isShuffled { next.shuffle() }
        order = next
        currentIndex = 0
    }
```

with a smaller helper plus the rewritten `toggleShuffle`:

```swift
    private func recomputeOrder() -> [AlphabetItem] {
        var next = Self.filteredOrder(allItems: allItems, manifest: manifest, filters: selectedFilters)
        if isShuffled { next.shuffle() }
        return next
    }

    /// If `previousFocusedItem` still exists in `newOrder`, stay on it
    /// (wherever it now sits). Otherwise walk forward through
    /// `allItemsInOriginalOrder` starting just after its old position,
    /// wrapping around, until finding the first item that survived into
    /// `newOrder` — pure and unit-tested independent of `self` so filter
    /// fallback behavior can be verified without constructing a full view
    /// model.
    static func resolveFocusIndex(
        previousFocusedItem: AlphabetItem?, allItemsInOriginalOrder: [AlphabetItem], newOrder: [AlphabetItem]
    ) -> Int {
        guard let previousFocusedItem else { return 0 }
        if let sameIndex = newOrder.firstIndex(where: { $0.id == previousFocusedItem.id }) {
            return sameIndex
        }
        guard !newOrder.isEmpty,
              let startPosition = allItemsInOriginalOrder.firstIndex(where: { $0.id == previousFocusedItem.id })
        else { return 0 }
        let idsInNewOrder = Set(newOrder.map(\.id))
        for offset in 1..<allItemsInOriginalOrder.count {
            let candidateIndex = (startPosition + offset) % allItemsInOriginalOrder.count
            let candidate = allItemsInOriginalOrder[candidateIndex]
            if idsInNewOrder.contains(candidate.id),
               let resolvedIndex = newOrder.firstIndex(where: { $0.id == candidate.id }) {
                return resolvedIndex
            }
        }
        return 0
    }

    func toggleShuffle() {
        isShuffled.toggle()
        order = recomputeOrder()
        currentIndex = 0
        lastIndexChangeAnimates = false
        notifyPreferencesChanged()
    }
```

Note `toggleShuffle()` already existed elsewhere in the file (right after `toggleFilter`) — delete its old body (the one still calling `refreshOrder()`) rather than ending up with two declarations:

```swift
    func toggleShuffle() {
        isShuffled.toggle()
        refreshOrder()
        notifyPreferencesChanged()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' -only-testing:AlphaBetaTests/CardDeckViewModelTests 2>&1 | tail -80`
Expected: PASS — every test in the file passes, including the new filter-fallback, `resolveFocusIndex`, and shuffle-reset tests.

- [ ] **Step 5: Commit**

```bash
git add Features/Cards/CardDeckViewModel.swift AlphaBetaTests/CardDeckViewModelTests.swift
git commit -m "Filter changes stay on the focused item (or walk forward to the next visible one); shuffle resets focus to the first shuffled item"
```

---

### Task 4: `WrapIndicatorView` — the native-style wrap capsule

**Files:**
- Create: `Features/Cards/WrapIndicatorView.swift`

**Interfaces:**
- Consumes: `CardDeckViewModel.WrapEvent` from Task 2.
- Produces: `WrapIndicatorView` (a `View` taking `let event: CardDeckViewModel.WrapEvent`). Task 5's `CardCarouselView` consumes this.

No unit test for this task — it's pure SwiftUI presentation with no logic branch worth a unit test beyond what a compiler already enforces (matches this project's existing convention for view-only files like `CardFaceView`). It's visually verified as part of Task 6's Simulator check.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// The "you've completed the set and wrapped around" indicator, per
/// docs/superpowers/specs/2026-07-11-card-carousel-design.md: an iOS-native
/// capsule (material background, SF Symbol, short text) rather than an
/// Android-style toast. `CardCarouselView` shows this for ~1.5s whenever
/// `CardDeckViewModel.wrapEvent` becomes non-nil.
struct WrapIndicatorView: View {
    let event: CardDeckViewModel.WrapEvent

    private var symbolName: String {
        switch event {
        case .forward: "arrow.uturn.backward"
        case .backward: "arrow.uturn.forward"
        }
    }

    private var message: String {
        switch event {
        case .forward: "Back to the beginning"
        case .backward: "Back to the end"
        }
    }

    var body: some View {
        Label(message, systemImage: symbolName)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Features/Cards/WrapIndicatorView.swift
git commit -m "Add WrapIndicatorView, the native-style capsule shown on carousel wraparound"
```

---

### Task 5: `CardCarouselView` — the paged/peeking carousel, wired into `CardsView`

**Files:**
- Create: `Features/Cards/CardCarouselView.swift`
- Delete: `Features/Cards/CardDeckView.swift`
- Modify: `Features/Cards/CardsView.swift:49-72` (the `body`'s `VStack`, currently constructing `CardDeckView`)

**Interfaces:**
- Consumes (all from earlier tasks): `CardDeckViewModel.carouselEntries`, `.entryID(at:)`, `.handleScrollSettled(to:)`, `.focusNeighbor(_:)`, `.wrapEvent`, `.clearWrapEvent()`, `.lastIndexChangeAnimates`, `.currentIndex`; `WrapIndicatorView`; `CardFaceView` (unchanged, existing).
- Produces: `CardCarouselView` (a `View` taking `let viewModel: CardDeckViewModel` and `var onTapFocusedItem: (AlphabetItem) -> Void`). `CardsView` consumes this.

No unit test for this task (pure SwiftUI view/gesture code — same convention as Task 4). Verified manually in Simulator as part of Task 6.

- [ ] **Step 1: Create `CardCarouselView.swift`**

```swift
import SwiftUI

/// The paged, peeking carousel that replaces the old swipe-to-dismiss
/// `CardDeckView`, per docs/superpowers/specs/2026-07-11-card-carousel-design.md.
/// Nothing is discarded when you swipe — paging only changes which card is
/// focused. Tapping the focused (centered) card opens its detail sheet;
/// tapping a peeking neighbor brings it into focus instead.
struct CardCarouselView: View {
    let viewModel: CardDeckViewModel
    var onTapFocusedItem: (AlphabetItem) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollTargetID: String?
    @State private var showWrapIndicator = false
    /// Suppresses the page-settle haptic for the very first `scrollTargetID`
    /// assignment in `onAppear` — that's the carousel loading, not a swipe.
    @State private var hasAppeared = false

    /// Fixed absolute size on both iPhone and iPad, per the design doc's
    /// iPad-sizing section — iPad's extra width becomes more peek instead of
    /// a bigger card.
    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 360
    private let cardSpacing: CGFloat = 16
    /// ~20% of the card width peeks in on each side at rest, per the
    /// approved visual-companion review ("moderate peek").
    private let peekFraction: CGFloat = 0.2

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: cardSpacing) {
                    ForEach(viewModel.carouselEntries) { entry in
                        CardFaceView(
                            item: entry.item, manifest: viewModel.manifest,
                            allItems: viewModel.allItems, hideNames: viewModel.hideNames
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.35)
                                .scaleEffect(phase.isIdentity ? 1 : 0.86)
                        }
                        .onTapGesture {
                            if entry.id == scrollTargetID {
                                onTapFocusedItem(entry.item)
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.focusNeighbor(entry.item)
                                }
                            }
                        }
                        .id(entry.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollTargetID)
            .safeAreaPadding(.horizontal, cardWidth * peekFraction)
            .onAppear {
                scrollTargetID = viewModel.entryID(at: viewModel.currentIndex)
                hasAppeared = true
            }
            .onChange(of: scrollTargetID) { _, newID in
                viewModel.handleScrollSettled(to: newID)
                // Matches the light-impact haptic the old swipe-to-dismiss
                // deck gave on every completed swipe (SPEC §5) — fires when
                // paging settles on a real card, not on the initial load or
                // on landing on a sentinel (the wrap indicator's own
                // `.selection()` haptic covers that case instead).
                if hasAppeared, let newID, newID.hasPrefix("real-") {
                    Haptics.impactLight()
                }
            }
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                let newID = viewModel.entryID(at: newIndex)
                if viewModel.lastIndexChangeAnimates {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scrollTargetID = newID
                    }
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        scrollTargetID = newID
                    }
                }
            }
            .onChange(of: viewModel.wrapEvent) { _, newEvent in
                guard newEvent != nil else { return }
                Haptics.selection()
                withAnimation(reduceMotion ? .easeInOut : .spring(response: 0.3, dampingFraction: 0.8)) {
                    showWrapIndicator = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showWrapIndicator = false
                    }
                    viewModel.clearWrapEvent()
                }
            }

            if showWrapIndicator, let event = viewModel.wrapEvent {
                WrapIndicatorView(event: event)
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
```

- [ ] **Step 2: Delete the old `CardDeckView.swift`**

```bash
rm Features/Cards/CardDeckView.swift
```

- [ ] **Step 3: Wire `CardCarouselView` into `CardsView`**

In `Features/Cards/CardsView.swift`, replace:

```swift
                if viewModel.count == 0 {
                    Spacer()
                    Text("Pick at least one category")
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                } else {
                    CardDeckView(viewModel: viewModel, reduceMotion: reduceMotion) { item in
                        detailItem = item
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 480, maxHeight: 640)

                    Text("\(viewModel.currentIndex + 1) / \(viewModel.count)")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.bottom, 8)
                }
```

with:

```swift
                if viewModel.count == 0 {
                    Spacer()
                    Text("Pick at least one category")
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                } else {
                    // Full width, not constrained to 480 — the carousel's
                    // card size is fixed internally, and the iPad's extra
                    // width beyond that fixed size is what becomes peek.
                    CardCarouselView(viewModel: viewModel) { item in
                        detailItem = item
                    }
                    .frame(maxWidth: .infinity)

                    Text("\(viewModel.currentIndex + 1) / \(viewModel.count)")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.bottom, 8)
                }
```

Then remove the now-unused `reduceMotion` property — `CardCarouselView` reads `@Environment(\.accessibilityReduceMotion)` itself (same pattern already used elsewhere, e.g. `ItemDetailSheet` reading its own environment values directly rather than having them passed in). Delete this line from `CardsView`'s property list:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

- [ ] **Step 4: Commit**

```bash
git add Features/Cards/CardCarouselView.swift Features/Cards/CardsView.swift
git rm Features/Cards/CardDeckView.swift
git commit -m "Replace CardDeckView's swipe-to-dismiss stack with CardCarouselView's paged carousel"
```

---

### Task 6: Update SPEC.md, regenerate the Xcode project, build, test, verify in Simulator, commit

**Files:**
- Modify: `SPEC.md`

- [ ] **Step 1: Update SPEC.md §5 (Cards tab) and its iPad note**

Find the Cards tab description in §5 and the iPad-specific note about the deck's `480×640` constraint and the already-centered `FilterPillBar`. Rewrite the deck description to describe the carousel instead: a horizontally-paged, peeking carousel (nothing discarded on swipe, ~20% neighbor peek on iPhone), tapping the focused card opens the detail sheet, tapping a peeking neighbor focuses it, changing a filter keeps focus on the same letter (or advances to the next visible one in alphabet order if it was filtered out), toggling shuffle resets focus to the first shuffled card, and swiping past either end wraps around with a brief native-style capsule indicator ("Back to the beginning" / "Back to the end"). Update the iPad note to say the carousel keeps the same fixed card size as iPhone, with the extra width becoming a larger peek rather than a bigger card — alongside the already-centered `FilterPillBar`.

- [ ] **Step 2: Regenerate the Xcode project**

```bash
~/bin/xcodegen_dist/bin/xcodegen generate
```

Expected: regenerates `AlphaBeta.xcodeproj` picking up the new `WrapIndicatorView.swift`/`CardCarouselView.swift` files and the removed `CardDeckView.swift`.

- [ ] **Step 3: Build for iPhone and iPad simulators**

```bash
xcodebuild -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' build 2>&1 | tail -30
xcodebuild -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=08B50418-A893-4125-94C9-119B6CAEDCDE' build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **` for both.

- [ ] **Step 4: Run the full test suite**

```bash
xcodebuild test -project AlphaBeta.xcodeproj -scheme AlphaBeta -destination 'id=41E3CEAB-05B3-4186-83D7-926F525AA8E9' 2>&1 | tail -40
```

Expected: all suites pass, with no reference to `CardDeckView`, `advance()`, `retreat()`, or `peekItems(_:)` remaining anywhere in the codebase (`grep -rn "peekItems\|CardDeckView\b" --include="*.swift" .` should return nothing outside of this plan/spec's own prose).

- [ ] **Step 5: Manually verify in Simulator**

```bash
xcrun simctl boot 41E3CEAB-05B3-4186-83D7-926F525AA8E9 2>&1
xcrun simctl install 41E3CEAB-05B3-4186-83D7-926F525AA8E9 /path/to/DerivedData/.../AlphaBeta.app
xcrun simctl launch 41E3CEAB-05B3-4186-83D7-926F525AA8E9 <bundle-id>
```

Check, on iPhone:
- Cards tab shows one focused card with both neighbors peeking ~20% at the edges.
- Swiping left/right pages one card at a time with animated, physics-driven paging, with a light-impact haptic each time paging settles on a new card (matching the old deck's per-swipe haptic).
- Tapping a peeking neighbor animates it into focus; tapping the now-focused card opens `ItemDetailSheet`.
- Toggling a filter pill: if the focused letter still passes, it stays focused; if not, focus jumps (no animated travel) to the next visible letter in alphabet order.
- Toggling shuffle resets focus to the first shuffled card.
- Swiping past the last card wraps to the first, showing the "Back to the beginning" capsule with a haptic tick, auto-dismissing after ~1.5s; swiping backward past the first card wraps to the last with "Back to the end."

Repeat the same checks on iPad, additionally confirming the focused card is the same absolute size as on iPhone and neighbors show more of themselves (larger peek) than on iPhone.

If the peek doesn't visually read as "moderate ~20%" once you see it at real size, adjust `cardWidth`/`cardHeight`/`peekFraction` in `CardCarouselView` and rebuild — those three constants are the only tuning knobs.

- [ ] **Step 6: Commit**

```bash
git add SPEC.md
git commit -m "Update SPEC.md Cards tab description for the paged carousel"
```
