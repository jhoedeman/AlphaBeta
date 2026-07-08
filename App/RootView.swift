import SwiftUI

/// Placeholder shell for M1. Confirms the content pipeline loads by listing
/// the bundled languages; the real Cards/Quiz `TabView` lands in M3/M6.
struct RootView: View {
    @State private var languages: [LanguageManifest] = []
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            List {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(languages) { language in
                    Label(language.displayName, systemImage: "character.book.closed")
                }
            }
            .navigationTitle("AlphaBeta")
        }
        .task {
            do {
                languages = try LanguageRegistry().languages
            } catch {
                loadError = "Failed to load Manifest.json: \(error)"
            }
        }
    }
}

#Preview {
    RootView()
}
