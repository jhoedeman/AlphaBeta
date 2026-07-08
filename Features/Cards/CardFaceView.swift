import SwiftUI

/// The visual face of a single card, per SPEC §5 "Card face". Pure
/// presentation — all navigation/gesture handling lives in `CardDeckView`.
struct CardFaceView: View {
    let item: AlphabetItem
    let manifest: LanguageManifest
    let allItems: [AlphabetItem]
    var hideNames = false

    @Environment(ThemeManager.self) private var theme

    private var caseSiblings: [AlphabetItem] {
        item.caseSiblings(in: allItems)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack(alignment: .topTrailing) {
                Text(item.foreignLetter)
                    .font(.custom("Athelas-Bold", size: 180))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(theme.accent)
                if let markedVersion = item.markedVersion {
                    // Athelas is missing glyphs for some accented Greek capitals
                    // (Έ, Ή, Ί, Ύ); the system serif has full Unicode coverage.
                    Text(markedVersion)
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.accent.opacity(0.6))
                        .offset(x: 20, y: -4)
                }
            }

            if !hideNames {
                Text(item.englishName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                if let foreignLetterName = item.foreignLetterName {
                    Text(foreignLetterName)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()

            HStack {
                if !caseSiblings.isEmpty {
                    Text(caseSiblings.map(\.foreignLetter).joined(separator: "  "))
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Text(item.category(hasLetterCase: manifest.hasLetterCase).displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}
