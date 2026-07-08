import SwiftUI

/// Placeholder for M4. Confirms the tap-to-detail affordance from SPEC §5
/// works end-to-end; the full sections (pronunciation, example word, case
/// forms, etc.) land in M4 per SPEC §6.
struct ItemDetailSheet: View {
    let item: AlphabetItem

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
            Text(item.foreignLetter)
                .font(.custom("Athelas-Bold", size: 140))
                .foregroundStyle(theme.accent)
            Text(item.englishName)
                .font(.title)
                .foregroundStyle(theme.textPrimary)
            Text("Full detail arrives in M4")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
