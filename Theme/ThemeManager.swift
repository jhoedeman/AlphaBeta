import SwiftUI

/// Resolves the active `Palette` and exposes its tokens as `Color`s for the
/// current color scheme. Per SPEC §8.1: custom palette → user-picked stock
/// palette → selected language's default palette; then light/dark variant
/// from the appearance setting.
///
/// Persisted fields (`appearance`, `paletteOverrideID`, `customPalette`) live
/// in-memory here until M8 wires them to `UserPreferences` (SwiftData).
@Observable
final class ThemeManager {
    enum Appearance: String, CaseIterable {
        case system, light, dark
    }

    private let paletteRegistry: PaletteRegistry

    var appearance: Appearance = .system
    var languageDefaultPaletteID: String
    var paletteOverrideID: String?
    var customPalette: Palette?

    /// Synced from `@Environment(\.colorScheme)` by the root view, since
    /// `ThemeManager` isn't a `View` and can't read the environment itself.
    var systemColorScheme: ColorScheme = .light

    init(paletteRegistry: PaletteRegistry, languageDefaultPaletteID: String) {
        self.paletteRegistry = paletteRegistry
        self.languageDefaultPaletteID = languageDefaultPaletteID
    }

    var activePalette: Palette {
        if let customPalette {
            return customPalette
        }
        if let paletteOverrideID, let palette = paletteRegistry.palette(forID: paletteOverrideID) {
            return palette
        }
        return paletteRegistry.palette(forID: languageDefaultPaletteID) ?? Self.fallbackPalette
    }

    /// Passed to `.preferredColorScheme`; `nil` lets the system decide.
    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var resolvedScheme: ColorScheme {
        switch appearance {
        case .system: systemColorScheme
        case .light: .light
        case .dark: .dark
        }
    }

    private var tokens: ThemeColors {
        resolvedScheme == .dark ? activePalette.dark : activePalette.light
    }

    var background: Color { Color(hex: tokens.background) }
    var surface: Color { Color(hex: tokens.surface) }
    var accent: Color { Color(hex: tokens.accent) }
    var textPrimary: Color { Color(hex: tokens.textPrimary) }
    var textSecondary: Color { Color(hex: tokens.textSecondary) }

    private static let fallbackPalette = Palette(
        id: "fallback",
        name: "Fallback",
        light: ThemeColors(background: "#FFFFFF", surface: "#F2F2F2", accent: "#0D5EAF", textPrimary: "#000000", textSecondary: "#666666"),
        dark: ThemeColors(background: "#000000", surface: "#1C1C1E", accent: "#3D80FF", textPrimary: "#FFFFFF", textSecondary: "#AAAAAA")
    )
}

extension Color {
    /// Parses a `#RRGGBB` hex string. Malformed input falls back to black
    /// rather than crashing, since palette data is bundled JSON, not user input.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
