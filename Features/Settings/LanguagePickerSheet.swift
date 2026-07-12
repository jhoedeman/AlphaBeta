import SwiftUI

/// Language sheet per SPEC §9: languages grouped into sections by
/// `scriptFamily` ("Cyrillic ▸ Russian, Ukrainian, …"); a family with a
/// single language renders as a plain row instead of its own section.
struct LanguagePickerSheet: View {
    let registry: LanguageRegistry
    let currentLanguageID: Int
    let onSelect: (LanguageManifest) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        NavigationStack {
            List {
                ForEach(registry.groupedByScriptFamily, id: \.scriptFamily) { group in
                    if group.languages.count > 1 {
                        Section(group.scriptFamily.capitalized) {
                            ForEach(group.languages) { language in
                                row(for: language)
                            }
                        }
                    } else if let language = group.languages.first {
                        row(for: language)
                    }
                }
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for language: LanguageManifest) -> some View {
        Button {
            onSelect(language)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(language.flagEmoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    Text(language.nativeName)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if language.id == currentLanguageID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
