import SwiftUI

/// The visual face of a single card, per SPEC §5 "Card face". Pure
/// presentation — all navigation/gesture handling lives in `CardCarouselView`.
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
            Text(item.foreignLetter)
                .font(.custom("Athelas-Bold", size: 180))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .foregroundStyle(theme.accent)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.englishName), \(item.category(hasLetterCase: manifest.hasLetterCase).displayName.lowercased())")
        .accessibilityHint("Tap for details")
    }
}
