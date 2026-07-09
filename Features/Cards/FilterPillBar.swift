import SwiftUI

/// Multi-select filter pills plus the shuffle toggle, per SPEC §5. Pills come
/// from the manifest's `filterCategories`; a Quiz-side instance (§7.3) keeps
/// its own independent selection state.
struct FilterPillBar: View {
    let viewModel: CardDeckViewModel

    @Environment(ThemeManager.self) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var row: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.manifest.filterCategories, id: \.self) { category in
                pill(for: category)
            }
            shuffleButton
            hideNamesButton
        }
    }

    var body: some View {
        // Regular-width (iPad) has enough room to fit every pill without
        // scrolling, so it's centered above the constrained-width card
        // (SPEC §5) instead of leading-aligned across the full screen.
        if horizontalSizeClass == .regular {
            row
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                row
                    .padding(.horizontal)
            }
        }
    }

    private func pill(for category: FilterCategory) -> some View {
        let isActive = viewModel.selectedFilters.contains(category)
        return Text(category.displayName)
            .font(.subheadline.weight(.medium))
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? theme.accent : theme.surface)
            .foregroundStyle(isActive ? Color.white : theme.textPrimary)
            .clipShape(Capsule())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.toggleFilter(category)
                }
                Haptics.selection()
            }
    }

    private var shuffleButton: some View {
        Image(systemName: "shuffle")
            .font(.subheadline.weight(.semibold))
            .padding(10)
            .background(viewModel.isShuffled ? theme.accent : theme.surface)
            .foregroundStyle(viewModel.isShuffled ? Color.white : theme.textPrimary)
            .clipShape(Circle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.toggleShuffle()
                }
                Haptics.selection()
            }
    }

    /// Hides the letter/word names on the card face for self-quizzing —
    /// tapping the card still reveals them via the detail sheet.
    private var hideNamesButton: some View {
        Image(systemName: viewModel.hideNames ? "eye.slash" : "eye")
            .font(.subheadline.weight(.semibold))
            .padding(10)
            .background(viewModel.hideNames ? theme.accent : theme.surface)
            .foregroundStyle(viewModel.hideNames ? Color.white : theme.textPrimary)
            .clipShape(Circle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.toggleHideNames()
                }
                Haptics.selection()
            }
    }
}
