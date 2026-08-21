import SwiftUI

/// Onboarding screen 2: pick a starting language. Tapping a cell both
/// selects the language and completes onboarding in one action — no
/// separate "Continue" button, no skip.
struct LanguageGridScreen: View {
    let languageRegistry: LanguageRegistry
    let paletteRegistry: PaletteRegistry
    let onSelect: (LanguageManifest) -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var selectedID: Int?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose a language to start with")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 24)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(languageRegistry.languages) { manifest in
                        LanguageCell(
                            manifest: manifest,
                            tint: tintColor(for: manifest),
                            isSelected: selectedID == manifest.id
                        )
                        .onTapGesture { select(manifest) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func tintColor(for manifest: LanguageManifest) -> Color {
        guard let hex = paletteRegistry.palette(forID: manifest.defaultPaletteID)?.light.accent else {
            return theme.accent
        }
        return Color(hex: hex)
    }

    private func select(_ manifest: LanguageManifest) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedID = manifest.id
        }
        // Brief highlight before handing off, so the tap registers visually
        // before the view underneath swaps to the main TabView.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSelect(manifest)
        }
    }
}

private struct LanguageCell: View {
    let manifest: LanguageManifest
    let tint: Color
    let isSelected: Bool

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Text(manifest.nativeName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(manifest.displayName)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(tint.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(tint, lineWidth: isSelected ? 3 : 0)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
