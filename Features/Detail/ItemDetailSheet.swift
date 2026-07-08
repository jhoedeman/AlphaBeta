import SwiftUI

/// The full item detail, per SPEC §6: hero glyph, metadata chips,
/// pronunciation, example word, explanation, and (for letters) tappable
/// case-form mini-cards that swap the displayed item in place.
struct ItemDetailSheet: View {
    let manifest: LanguageManifest
    let allItems: [AlphabetItem]
    let pronunciationSystemID: String

    @State private var displayedItem: AlphabetItem

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    init(item: AlphabetItem, manifest: LanguageManifest, allItems: [AlphabetItem], pronunciationSystemID: String? = nil) {
        self.manifest = manifest
        self.allItems = allItems
        self.pronunciationSystemID = pronunciationSystemID ?? manifest.defaultPronunciationSystemID
        _displayedItem = State(initialValue: item)
    }

    private var caseSiblings: [(item: AlphabetItem, role: String)] {
        displayedItem.caseSiblingsWithRole(in: allItems)
    }

    private var pronunciation: PronunciationEntry? {
        displayedItem.pronunciation(preferring: pronunciationSystemID)
    }

    var body: some View {
        VStack(spacing: 0) {
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
            .padding([.top, .trailing])

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection
                    chipsRow
                    pronunciationSection
                    exampleWordSection
                    explanationSection
                    caseFormsSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(displayedItem.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // A fixed frame, not the glyph's own bounding box, anchors the
                // badge — Athelas' per-glyph metrics vary enough (e.g. "Ε" vs
                // "Α") that anchoring to the Text's intrinsic frame let the
                // badge overlap letters with a shorter visible ascender.
                Text(displayedItem.foreignLetter)
                    .font(.custom("Athelas-Bold", size: 140))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(theme.accent)
                    .frame(width: 200, height: 160)
                if let markedVersion = displayedItem.markedVersion {
                    VStack(spacing: 2) {
                        Text(markedVersion)
                            .font(.system(size: 32, weight: .semibold, design: .serif))
                            .foregroundStyle(theme.accent.opacity(0.6))
                        Text("with accent")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .fixedSize()
                    .offset(x: 8, y: -12)
                }
            }
            .frame(maxWidth: .infinity)

            Text(displayedItem.englishName)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            if let foreignLetterName = displayedItem.foreignLetterName {
                Text(foreignLetterName)
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Category alone already says "Capitals"/"Lowercase" for letters — a
    // separate capital/lowercase chip would just restate it.
    private var chipsRow: some View {
        HStack(spacing: 8) {
            chip(displayedItem.category(hasLetterCase: manifest.hasLetterCase).displayName)
            if let isVowel = displayedItem.isVowel {
                chip(isVowel ? "Vowel" : "Consonant")
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var pronunciationSection: some View {
        if let pronunciation, (pronunciation.full != nil || pronunciation.short != nil) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pronunciation")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    if manifest.pronunciationSystems.count > 1,
                       let systemName = manifest.pronunciationSystems
                           .first(where: { $0.id == pronunciationSystemID })?.displayName {
                        Text(systemName)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    // Audio designed-for, not shipped in v1 (SPEC §11) — slot
                    // reserved so the layout doesn't shift when it lands.
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(theme.accent)
                        .hidden()
                }
                if let short = pronunciation.short {
                    Text("Sounds like: \(short)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.accent)
                }
                if let full = pronunciation.full {
                    Text(full)
                        .font(.body)
                        .foregroundStyle(theme.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var exampleWordSection: some View {
        if let parsed = displayedItem.parsedExampleWord {
            VStack(alignment: .leading, spacing: 8) {
                Text("Example word")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(parsed.word)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.accent)
                if let meaning = parsed.meaning {
                    Text("which means '\(meaning)'")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var explanationSection: some View {
        if let explanation = displayedItem.explanation {
            VStack(alignment: .leading, spacing: 8) {
                Text("Explanation")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var caseFormsSection: some View {
        if displayedItem.itemType == .letter, !caseSiblings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Case forms")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                HStack(spacing: 12) {
                    ForEach(caseSiblings, id: \.item.id) { sibling in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                displayedItem = sibling.item
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(sibling.item.foreignLetter)
                                    .font(.custom("Athelas-Bold", size: 32))
                                    .foregroundStyle(theme.accent)
                                Text(sibling.role)
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
