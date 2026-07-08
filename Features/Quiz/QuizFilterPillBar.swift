import SwiftUI

/// Filter pills for the quiz home screen, per SPEC §7.1 — "identical in
/// behavior/appearance to Cards view" but with its own selection state and
/// no shuffle/hide-names controls (those are Cards-only concerns).
struct QuizFilterPillBar: View {
    let viewModel: QuizViewModel

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.manifest.filterCategories, id: \.self) { category in
                    pill(for: category)
                }
            }
            .padding(.horizontal)
        }
    }

    private func pill(for category: FilterCategory) -> some View {
        let isActive = viewModel.selectedFilters.contains(category)
        return Text(category.displayName)
            .font(.subheadline.weight(.medium))
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
}
