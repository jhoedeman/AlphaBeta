import Testing
import SwiftUI
@testable import AlphaBeta

/// Palette-resolution and appearance-switching coverage for M2, per SPEC §8.1:
/// custom palette → user-picked stock palette → language default; then
/// light/dark variant from the appearance setting.
struct ThemeManagerTests {
    private static let greek = Palette(
        id: "greek-flag", name: "Hellenic Blue",
        light: ThemeColors(background: "#F8FAFF", surface: "#FFFFFF", accent: "#1055E8", textPrimary: "#1A2845", textSecondary: "#3D5A85"),
        dark: ThemeColors(background: "#0D1625", surface: "#152040", accent: "#3D80FF", textPrimary: "#EEF2FD", textSecondary: "#8FA4C8")
    )
    private static let russian = Palette(
        id: "russian-flag", name: "Tricolor Red",
        light: ThemeColors(background: "#FAFAFA", surface: "#FFFFFF", accent: "#C41E1E", textPrimary: "#27211D", textSecondary: "#57514B"),
        dark: ThemeColors(background: "#120A0A", surface: "#1E1010", accent: "#F94D45", textPrimary: "#F5F4F2", textSecondary: "#A8A19A")
    )
    private static let custom = Palette(
        id: "custom", name: "Custom",
        light: ThemeColors(background: "#111111", surface: "#222222", accent: "#333333", textPrimary: "#444444", textSecondary: "#555555"),
        dark: ThemeColors(background: "#666666", surface: "#777777", accent: "#888888", textPrimary: "#999999", textSecondary: "#AAAAAA")
    )

    private func makeManager() -> ThemeManager {
        let registry = PaletteRegistry(palettes: [Self.greek, Self.russian])
        return ThemeManager(paletteRegistry: registry, languageDefaultPaletteID: "greek-flag")
    }

    @Test func defaultsToLanguagePalette() {
        let manager = makeManager()
        #expect(manager.activePalette.id == "greek-flag")
    }

    @Test func stockOverrideBeatsLanguageDefault() {
        let manager = makeManager()
        manager.paletteOverrideID = "russian-flag"
        #expect(manager.activePalette.id == "russian-flag")
    }

    @Test func customPaletteBeatsStockOverride() {
        let manager = makeManager()
        manager.paletteOverrideID = "russian-flag"
        manager.customPalette = Self.custom
        #expect(manager.activePalette.id == "custom")
    }

    @Test func unknownOverrideFallsBackToLanguageDefault() {
        let manager = makeManager()
        manager.paletteOverrideID = "nonexistent"
        #expect(manager.activePalette.id == "greek-flag")
    }

    @Test func systemAppearanceFollowsColorScheme() {
        let manager = makeManager()
        manager.appearance = .system

        manager.systemColorScheme = .light
        #expect(manager.background == Color(hex: Self.greek.light.background))

        manager.systemColorScheme = .dark
        #expect(manager.background == Color(hex: Self.greek.dark.background))
    }

    @Test func explicitAppearanceIgnoresSystemColorScheme() {
        let manager = makeManager()
        manager.systemColorScheme = .light

        manager.appearance = .dark
        #expect(manager.background == Color(hex: Self.greek.dark.background))

        manager.appearance = .light
        #expect(manager.background == Color(hex: Self.greek.light.background))
    }

    @Test func preferredColorSchemeIsNilOnlyForSystem() {
        let manager = makeManager()
        manager.appearance = .system
        #expect(manager.preferredColorScheme == nil)

        manager.appearance = .light
        #expect(manager.preferredColorScheme == .light)

        manager.appearance = .dark
        #expect(manager.preferredColorScheme == .dark)
    }
}
