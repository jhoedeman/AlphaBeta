import SwiftUI

/// The question prompt, "styled like the Cards-view cards" per SPEC §7.3.
/// `.glyphToName` questions show the subject glyph large, matching Q1's
/// "show `foreignLetter`" spec; every other type is prompt-text-only since
/// the glyph itself is what's being guessed at (options), not given away.
struct QuestionCardView: View {
    let question: QuizQuestion
    let subjectItem: AlphabetItem?

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 16) {
            if question.type == .glyphToName, let subjectItem {
                Text(subjectItem.foreignLetter)
                    .font(.custom("Athelas-Bold", size: 96))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(theme.accent)
            }
            Text(question.prompt)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textPrimary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}
