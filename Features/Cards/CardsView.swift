import SwiftUI

/// Cards tab root, per SPEC §5: filter pills + shuffle above, the swipeable
/// deck centered (constrained to 480x640 on iPad), a card-count indicator
/// below, and a friendly empty state when every filter is deselected.
struct CardsView: View {
    @State private var viewModel: CardDeckViewModel
    @State private var detailItem: AlphabetItem?

    @Environment(ThemeManager.self) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(manifest: LanguageManifest, items: [AlphabetItem]) {
        _viewModel = State(initialValue: CardDeckViewModel(manifest: manifest, allItems: items))
    }

    var body: some View {
        VStack(spacing: 12) {
            FilterPillBar(viewModel: viewModel)

            if viewModel.count == 0 {
                Spacer()
                Text("Pick at least one category")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            } else {
                CardDeckView(viewModel: viewModel) { item in
                    detailItem = item
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 480, maxHeight: 640)

                Text("\(viewModel.currentIndex + 1) / \(viewModel.count)")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .sheet(item: $detailItem) { item in
            // iPhone: full-height sheet with a drag handle for the
            // interactive pull-down dismiss SPEC §6 asks for, alongside the
            // chevron button. iPad: a centered form sheet, per the same spec.
            if horizontalSizeClass == .regular {
                ItemDetailSheet(item: item, manifest: viewModel.manifest, allItems: viewModel.allItems)
                    .presentationSizing(.form)
            } else {
                ItemDetailSheet(item: item, manifest: viewModel.manifest, allItems: viewModel.allItems)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
