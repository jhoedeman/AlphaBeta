import SwiftUI

/// One tappable answer tile, per SPEC §7.3: selection highlights with the
/// theme accent; once revealed, the correct option tints green and a wrong
/// pick tints red.
struct QuizOptionRow: View {
    let option: QuizOption
    let isSelected: Bool
    let isRevealed: Bool
    let onTap: () -> Void

    @Environment(ThemeManager.self) private var theme

    private var background: Color {
        guard isRevealed else { return isSelected ? theme.accent.opacity(0.2) : theme.surface }
        if option.isCorrect { return .green.opacity(0.25) }
        if isSelected { return .red.opacity(0.25) }
        return theme.surface
    }

    private var borderColor: Color {
        guard isRevealed else { return isSelected ? theme.accent : .clear }
        if option.isCorrect { return .green }
        if isSelected { return .red }
        return .clear
    }

    var body: some View {
        Text(option.text)
            .font(.body.weight(.medium))
            .foregroundStyle(theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}
