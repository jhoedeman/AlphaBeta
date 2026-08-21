import SwiftUI

/// Onboarding screen 1: a short value-prop pitch before the language picker.
struct IntroScreen: View {
    let onContinue: () -> Void

    @Environment(ThemeManager.self) private var theme

    private let pillars: [(symbol: String, text: String)] = [
        ("rectangle.stack", "Swipeable flashcards for every letter"),
        ("graduationcap.fill", "An adaptive quiz that learns what you're still working on"),
        ("flame.fill", "Daily streaks to keep you coming back"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(theme.accent)

                Text("Alpha|Beta")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.textPrimary)

                Text("Learn to read Greek, Cyrillic, and more — one letter at a time.")
                    .font(.body)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 20) {
                ForEach(pillars, id: \.text) { pillar in
                    Label {
                        Text(pillar.text)
                            .foregroundStyle(theme.textPrimary)
                    } icon: {
                        Image(systemName: pillar.symbol)
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(theme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
