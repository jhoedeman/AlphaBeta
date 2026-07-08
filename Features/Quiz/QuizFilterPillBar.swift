import SwiftUI

/// Filter selector for the quiz home screen, per SPEC §7.1. Unlike the
/// Cards view's scrolling pill bar, this has room for a two-column tile
/// grid — a fixed row count doesn't work here since the category count
/// varies by language (most Cyrillic languages ship 2, Greek/Armenian
/// ship 4, and future scripts may add more), so the grid keeps its column
/// count fixed at 2 and simply grows or shrinks the row count instead.
struct QuizFilterPillBar: View {
    let viewModel: QuizViewModel

    @Environment(ThemeManager.self) private var theme

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.manifest.filterCategories, id: \.self) { category in
                tile(for: category)
            }
        }
        .padding(.horizontal, 24)
    }

    private func tile(for category: FilterCategory) -> some View {
        let isActive = viewModel.selectedFilters.contains(category)
        return Text(category.displayName)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isActive ? Color.white : theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isActive ? theme.accent : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.toggleFilter(category)
                }
                Haptics.selection()
            }
    }
}
