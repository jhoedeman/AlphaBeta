import Testing
@testable import AlphaBeta

/// Filter/shuffle/navigation coverage for M3's `CardDeckViewModel`, per
/// SPEC §5: JSON-order default, wraparound advance/retreat, and a friendly
/// empty state when every filter is deselected.
struct CardDeckViewModelTests {
    private static let manifest = LanguageManifest(
        id: 1, code: "el", displayName: "Greek", nativeName: "Ελληνικά",
        scriptFamily: "Greek", fileName: "Greek", readingDirection: .leftToRight,
        hasLetterCase: true,
        pronunciationSystems: [PronunciationSystem(id: "modern", displayName: "Modern")],
        filterCategories: [.capitals, .lowercase, .diphthongs],
        defaultPaletteID: "greek-flag", flagEmoji: "🇬🇷"
    )

    private static func item(_ id: Int, _ letter: String, type: ItemType = .letter) -> AlphabetItem {
        AlphabetItem(
            identifier: id, itemType: type, englishName: "Letter \(id)", foreignLetter: letter,
            exampleWord: nil, isVowel: nil, pronunciations: [:], languageSubtype: nil,
            foreignLetterName: nil, markedVersion: nil, markedCaseEquivalent: nil,
            caseEquivalent: nil, leadingCaseEquivalent: nil, middleCaseEquivalent: nil,
            endingCaseEquivalent: nil, lowercaseEnglishName: nil, explanation: nil
        )
    }

    private static let capitalA = item(1, "A")
    private static let lowerA = item(2, "a")
    private static let diphthong = item(3, "ai", type: .diphthong)
    private static let items = [capitalA, lowerA, diphthong]

    private func makeViewModel() -> CardDeckViewModel {
        CardDeckViewModel(manifest: Self.manifest, allItems: Self.items)
    }

    @Test func defaultsToAllFiltersAndManifestOrder() {
        let viewModel = makeViewModel()
        #expect(viewModel.selectedFilters == Set(Self.manifest.filterCategories))
        #expect(viewModel.count == 3)
        #expect(viewModel.currentItem?.id == Self.capitalA.id)
    }

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

    @Test func togglingOffAllFiltersEmptiesTheDeck() {
        let viewModel = makeViewModel()
        for category in Self.manifest.filterCategories {
            viewModel.toggleFilter(category)
        }
        #expect(viewModel.count == 0)
        #expect(viewModel.currentItem == nil)
    }

    @Test func toggleFilterNarrowsToMatchingCategory() {
        let viewModel = makeViewModel()
        viewModel.toggleFilter(.lowercase)
        viewModel.toggleFilter(.diphthongs)
        #expect(viewModel.count == 1)
        #expect(viewModel.currentItem?.id == Self.capitalA.id)
    }

    @Test func filterChangeResetsCurrentIndex() {
        let viewModel = makeViewModel()
        viewModel.focusNeighbor(Self.lowerA)
        #expect(viewModel.currentIndex == 1)
        viewModel.toggleFilter(.diphthongs)
        #expect(viewModel.currentIndex == 0)
    }

    @Test func shuffleContainsSameItemsInSomeOrder() {
        let viewModel = makeViewModel()
        viewModel.toggleShuffle()
        #expect(Set(viewModel.order.map(\.id)) == Set(Self.items.map(\.id)))
        #expect(viewModel.isShuffled)

        viewModel.toggleShuffle()
        #expect(!viewModel.isShuffled)
        #expect(viewModel.order.map(\.id) == Self.items.map(\.id))
    }

    // MARK: - M9: restored preferences + persistence callback

    @Test func initialFiltersAndShuffledRestorePersistedState() {
        let viewModel = CardDeckViewModel(
            manifest: Self.manifest, allItems: Self.items,
            initialFilters: [.lowercase], initialShuffled: true
        )
        #expect(viewModel.selectedFilters == [.lowercase])
        #expect(viewModel.isShuffled)
        #expect(viewModel.count == 1)
    }

    @Test func toggleFilterInvokesPersistenceCallbackWithSortedRawValues() {
        var reported: (filterRaw: String, isShuffled: Bool)?
        let viewModel = CardDeckViewModel(
            manifest: Self.manifest, allItems: Self.items,
            onPreferencesChanged: { filterRaw, isShuffled in reported = (filterRaw, isShuffled) }
        )
        viewModel.toggleFilter(.diphthongs)
        #expect(reported?.filterRaw == "capitals,lowercase")
        #expect(reported?.isShuffled == false)
    }

    @Test func toggleShuffleInvokesPersistenceCallback() {
        var reportedShuffled: Bool?
        let viewModel = CardDeckViewModel(
            manifest: Self.manifest, allItems: Self.items,
            onPreferencesChanged: { _, isShuffled in reportedShuffled = isShuffled }
        )
        viewModel.toggleShuffle()
        #expect(reportedShuffled == true)
    }

    @Test func filterCategorySetParsesCommaJoinedRawValuesIgnoringUnknowns() {
        let parsed = FilterCategory.set(fromCommaJoinedRawValues: "capitals,bogus,lowercase")
        #expect(parsed == [.capitals, .lowercase])
    }

    @Test func filterCategorySetOfEmptyStringIsEmpty() {
        #expect(FilterCategory.set(fromCommaJoinedRawValues: "").isEmpty)
    }

    // MARK: - Carousel entries, wrap, and neighbor focus

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
}
