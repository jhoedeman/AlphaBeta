import SwiftUI

/// Settings sheet per SPEC §9: appearance, color scheme (stock palettes +
/// custom builder + reset), pronunciation system, and an about footer.
struct SettingsSheet: View {
    let manifest: LanguageManifest
    let paletteRegistry: PaletteRegistry
    let preferencesStore: UserPreferencesStore

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    private var resolvedPronunciationSystemID: String {
        manifest.resolvedPronunciationSystemID(preferring: preferencesStore.pronunciationSystemID)
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                colorSchemeSection
                pronunciationSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Form's chrome otherwise follows the real system colorScheme, not
        // ThemeManager's in-app override — sheets get a fresh presentation
        // context that doesn't inherit RootView's `.preferredColorScheme`.
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: appearanceBinding) {
                ForEach(ThemeManager.Appearance.allCases, id: \.self) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var appearanceBinding: Binding<ThemeManager.Appearance> {
        Binding(
            get: { theme.appearance },
            set: { newValue in
                theme.appearance = newValue
                preferencesStore.setAppearance(newValue.rawValue)
            }
        )
    }

    private var colorSchemeSection: some View {
        Section("Color Scheme") {
            ForEach(paletteRegistry.palettes) { palette in
                paletteRow(palette)
            }
            NavigationLink {
                PaletteBuilderView(startingFrom: theme.activePalette) { built in
                    theme.customPalette = built
                    if let data = try? JSONEncoder().encode(built) {
                        preferencesStore.setCustomPalette(data)
                    }
                }
            } label: {
                Label("Custom…", systemImage: "paintpalette")
            }
            if theme.paletteOverrideID != nil || theme.customPalette != nil {
                Button("Reset to Language Default", role: .destructive) {
                    theme.paletteOverrideID = nil
                    theme.customPalette = nil
                    preferencesStore.setPalette(id: "")
                    preferencesStore.setCustomPalette(nil)
                }
            }
        }
    }

    private func paletteRow(_ palette: Palette) -> some View {
        let isActive = theme.customPalette == nil
            && (theme.paletteOverrideID == palette.id
                || (theme.paletteOverrideID == nil && theme.languageDefaultPaletteID == palette.id))
        return Button {
            theme.paletteOverrideID = palette.id
            theme.customPalette = nil
            preferencesStore.setPalette(id: palette.id)
            preferencesStore.setCustomPalette(nil)
        } label: {
            HStack {
                Circle()
                    .fill(Color(hex: palette.light.accent))
                    .frame(width: 20, height: 20)
                Text(palette.name)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paletteRow-\(palette.id)")
        .accessibilityValue(isActive ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private var pronunciationSection: some View {
        if manifest.pronunciationSystems.count > 1 {
            Section("Pronunciation") {
                Picker("Pronunciation System", selection: pronunciationBinding) {
                    ForEach(manifest.pronunciationSystems) { system in
                        Text(system.displayName).tag(system.id)
                    }
                }
            }
        } else {
            Section("Pronunciation") {
                HStack {
                    Text(manifest.pronunciationSystems.first?.displayName ?? "Modern")
                    Spacer()
                    Text("More coming soon")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private var pronunciationBinding: Binding<String> {
        Binding(
            get: { resolvedPronunciationSystemID },
            set: { preferencesStore.setPronunciationSystem(id: $0) }
        )
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersionString)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
