import SwiftUI

/// Custom palette builder per SPEC §8.2: `ColorPicker`s for each semantic
/// token, light and dark, pre-filled from the currently active palette so
/// building "starts" from something reasonable rather than blank white.
struct PaletteBuilderView: View {
    let onSave: (Palette) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var lightBackground: Color
    @State private var lightSurface: Color
    @State private var lightAccent: Color
    @State private var lightTextPrimary: Color
    @State private var lightTextSecondary: Color

    @State private var darkBackground: Color
    @State private var darkSurface: Color
    @State private var darkAccent: Color
    @State private var darkTextPrimary: Color
    @State private var darkTextSecondary: Color

    init(startingFrom palette: Palette, onSave: @escaping (Palette) -> Void) {
        self.onSave = onSave
        _lightBackground = State(initialValue: Color(hex: palette.light.background))
        _lightSurface = State(initialValue: Color(hex: palette.light.surface))
        _lightAccent = State(initialValue: Color(hex: palette.light.accent))
        _lightTextPrimary = State(initialValue: Color(hex: palette.light.textPrimary))
        _lightTextSecondary = State(initialValue: Color(hex: palette.light.textSecondary))
        _darkBackground = State(initialValue: Color(hex: palette.dark.background))
        _darkSurface = State(initialValue: Color(hex: palette.dark.surface))
        _darkAccent = State(initialValue: Color(hex: palette.dark.accent))
        _darkTextPrimary = State(initialValue: Color(hex: palette.dark.textPrimary))
        _darkTextSecondary = State(initialValue: Color(hex: palette.dark.textSecondary))
    }

    var body: some View {
        Form {
            Section("Light") {
                ColorPicker("Background", selection: $lightBackground)
                ColorPicker("Surface", selection: $lightSurface)
                ColorPicker("Accent", selection: $lightAccent)
                ColorPicker("Primary Text", selection: $lightTextPrimary)
                ColorPicker("Secondary Text", selection: $lightTextSecondary)
            }
            Section("Dark") {
                ColorPicker("Background", selection: $darkBackground)
                ColorPicker("Surface", selection: $darkSurface)
                ColorPicker("Accent", selection: $darkAccent)
                ColorPicker("Primary Text", selection: $darkTextPrimary)
                ColorPicker("Secondary Text", selection: $darkTextSecondary)
            }
        }
        .navigationTitle("Custom Palette")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(builtPalette)
                    dismiss()
                }
            }
        }
    }

    private var builtPalette: Palette {
        Palette(
            id: "custom", name: "Custom",
            light: ThemeColors(
                background: lightBackground.hexString, surface: lightSurface.hexString,
                accent: lightAccent.hexString, textPrimary: lightTextPrimary.hexString,
                textSecondary: lightTextSecondary.hexString
            ),
            dark: ThemeColors(
                background: darkBackground.hexString, surface: darkSurface.hexString,
                accent: darkAccent.hexString, textPrimary: darkTextPrimary.hexString,
                textSecondary: darkTextSecondary.hexString
            )
        )
    }
}
