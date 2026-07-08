import SwiftUI

/// Quiz tab root, per SPEC §7. Three states: pre-quiz filter/start screen,
/// the 10-question flow, and a bare score readout once finished — the
/// celebratory results sheet (confetti, streaks, "Another Quiz") lands in M7.
struct QuizView: View {
    @State private var viewModel: QuizViewModel

    @Environment(ThemeManager.self) private var theme

    init(manifest: LanguageManifest, items: [AlphabetItem], streakStore: StreakStore) {
        _viewModel = State(initialValue: QuizViewModel(manifest: manifest, allItems: items, streakStore: streakStore))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Quiz")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isFinished },
            set: { isPresented in if !isPresented { viewModel.returnToHome() } }
        )) {
            ResultsView(
                viewModel: viewModel,
                onAnotherQuiz: { viewModel.startQuiz() },
                onDone: { viewModel.returnToHome() }
            )
            .environment(theme)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.questions.isEmpty {
            homeView
        } else {
            questionFlowView
        }
    }

    private var homeView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent)
                Text("Test yourself")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("10 quick questions, weighted toward the letters you're still shaky on. Pick which categories to include, then start.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                if viewModel.streakStore.displayedStreak() > 0 {
                    Text("🔥 \(viewModel.streakStore.displayedStreak())-day streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
            Spacer()
            if viewModel.manifest.filterCategories.count > 1 {
                VStack(spacing: 10) {
                    Text("Choose what to test")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                    QuizFilterPillBar(viewModel: viewModel)
                }
            }
            Spacer()
            Button {
                viewModel.startQuiz()
            } label: {
                Text("Start Quiz")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.pool.isEmpty ? theme.accent.opacity(0.4) : theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(viewModel.pool.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var questionFlowView: some View {
        VStack(spacing: 20) {
            if let question = viewModel.currentQuestion {
                Text("\(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)

                VStack(spacing: 20) {
                    QuestionCardView(question: question, subjectItem: viewModel.subjectItem(for: question))
                    VStack(spacing: 10) {
                        ForEach(question.options) { option in
                            QuizOptionRow(
                                option: option,
                                isSelected: viewModel.selectedOptionID == option.id,
                                isRevealed: viewModel.isAnswerRevealed,
                                onTap: { viewModel.selectOption(option.id) }
                            )
                        }
                    }
                }
                .id(question.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()
                actionButton
            }
        }
        .padding(24)
    }

    private var actionButton: some View {
        Button {
            if viewModel.isAnswerRevealed {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.continueToNext()
                }
            } else {
                viewModel.submit()
            }
        } label: {
            Text(viewModel.isAnswerRevealed ? "Continue" : "Submit")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.canSubmit || viewModel.isAnswerRevealed ? theme.accent : theme.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!viewModel.canSubmit && !viewModel.isAnswerRevealed)
    }

}
