import Foundation

/// Filtering/ordering/navigation logic for the Cards deck, per SPEC §5. Kept
/// free of SwiftUI so it's unit-testable independent of gestures/animation.
@Observable
final class CardDeckViewModel {
    let manifest: LanguageManifest
    let allItems: [AlphabetItem]

    /// Persists filter/shuffle changes (SPEC §4 `cardFilterRaw`/`isShuffled`)
    /// without this view model knowing anything about SwiftData — same
    /// facade-closure pattern as `QuizViewModel`'s `UserDataPersisting`.
    private let onPreferencesChanged: (_ filterRaw: String, _ isShuffled: Bool) -> Void

    private(set) var selectedFilters: Set<FilterCategory>
    private(set) var isShuffled: Bool
    private(set) var hideNames = false
    private(set) var order: [AlphabetItem]
    private(set) var currentIndex = 0

    init(
        manifest: LanguageManifest, allItems: [AlphabetItem],
        initialFilters: Set<FilterCategory>? = nil, initialShuffled: Bool = false,
        onPreferencesChanged: @escaping (_ filterRaw: String, _ isShuffled: Bool) -> Void = { _, _ in }
    ) {
        self.manifest = manifest
        self.allItems = allItems
        self.onPreferencesChanged = onPreferencesChanged
        let resolvedFilters = initialFilters ?? Set(manifest.filterCategories)
        selectedFilters = resolvedFilters
        isShuffled = initialShuffled
        var initialOrder = Self.filteredOrder(allItems: allItems, manifest: manifest, filters: resolvedFilters)
        if initialShuffled { initialOrder.shuffle() }
        order = initialOrder
    }

    var count: Int { order.count }
    var currentItem: AlphabetItem? { order.isEmpty ? nil : order[currentIndex] }

    func toggleFilter(_ category: FilterCategory) {
        if selectedFilters.contains(category) {
            selectedFilters.remove(category)
        } else {
            selectedFilters.insert(category)
        }
        refreshOrder()
        notifyPreferencesChanged()
    }

    /// Reshuffles every time the deck transitions to shuffled, per SPEC §5
    /// ("reshuffles on each activation"); toggling off restores manifest order.
    func toggleShuffle() {
        isShuffled.toggle()
        refreshOrder()
        notifyPreferencesChanged()
    }

    private func notifyPreferencesChanged() {
        let filterRaw = selectedFilters.map(\.rawValue).sorted().joined(separator: ",")
        onPreferencesChanged(filterRaw, isShuffled)
    }

    /// Hides `englishName`/`foreignLetterName` on the card face for
    /// self-quizzing; tapping the card still opens the full detail sheet.
    /// Purely a display flag — doesn't touch filtering/order/index.
    func toggleHideNames() {
        hideNames.toggle()
    }

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

    private func refreshOrder() {
        var next = Self.filteredOrder(allItems: allItems, manifest: manifest, filters: selectedFilters)
        if isShuffled { next.shuffle() }
        order = next
        currentIndex = 0
    }

    private static func filteredOrder(allItems: [AlphabetItem], manifest: LanguageManifest, filters: Set<FilterCategory>) -> [AlphabetItem] {
        allItems.filter { filters.contains($0.category(hasLetterCase: manifest.hasLetterCase)) }
    }
}
