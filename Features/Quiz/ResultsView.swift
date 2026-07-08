import SwiftUI

/// Celebratory results sheet per SPEC §7.4: animated score count-up,
/// ring-progress fill, a confetti burst (skipped under Reduce Motion), a
/// per-question recap, and streak status.
struct ResultsView: View {
    let viewModel: QuizViewModel
    let onAnotherQuiz: () -> Void
    let onDone: () -> Void

    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ringProgress: Double = 0
    @State private var displayedScore = 0

    private var total: Int { viewModel.questions.count }
    private var scoreFraction: Double { total == 0 ? 0 : Double(viewModel.score) / Double(total) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    scoreRing
                        .padding(.top, 16)

                    Text("Quiz complete")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    streakCard

                    recapList
                }
                .padding(24)
            }
            .background(theme.background)
            .overlay {
                if !reduceMotion {
                    ConfettiView(intensity: scoreFraction)
                }
            }
            .safeAreaInset(edge: .bottom) {
                buttons
                    .padding(24)
                    .background(.bar)
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            displayedScore = reduceMotion ? viewModel.score : 0
            ringProgress = reduceMotion ? scoreFraction : 0
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.1)) {
                ringProgress = scoreFraction
            }
            withAnimation(.easeOut(duration: 1.1)) {
                displayedScore = viewModel.score
            }
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(theme.surface, lineWidth: 14)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(displayedScore) / \(total)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(width: 180, height: 180)
    }

    private var streakCard: some View {
        VStack(spacing: 6) {
            Text("🔥 \(viewModel.streakStore.currentStreak)-day streak\(viewModel.streakStore.currentStreak > 1 ? " — keep it going!" : "")")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            if viewModel.streakStore.longestStreak > viewModel.streakStore.currentStreak {
                Text("Longest streak: \(viewModel.streakStore.longestStreak) days")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            if viewModel.streakJustEarnedToday {
                Text("Today's streak credit earned")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var recapList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.answers) { answer in
                HStack(spacing: 12) {
                    Text(viewModel.subjectItem(for: answer.question)?.foreignLetter ?? "?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 36)
                    Text(answer.question.prompt)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: answer.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(answer.isCorrect ? .green : .red)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: onAnotherQuiz) {
                Text("Another Quiz")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
