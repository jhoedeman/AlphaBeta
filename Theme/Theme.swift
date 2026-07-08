import Foundation

/// A named light/dark color pair, distilled from a language's flag-inspired
/// color-system doc down to the five semantic tokens the app actually reads.
/// Views never hardcode a color — they read these tokens via `ThemeManager`.
struct Palette: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let light: ThemeColors
    let dark: ThemeColors
}

struct ThemeColors: Codable, Hashable, Sendable {
    let background: String
    let surface: String
    let accent: String
    let textPrimary: String
    let textSecondary: String
}
