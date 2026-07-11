import SwiftUI

/// The "you've completed the set and wrapped around" indicator, per
/// docs/superpowers/specs/2026-07-11-card-carousel-design.md: an iOS-native
/// capsule (material background, SF Symbol, short text) rather than an
/// Android-style toast. `CardCarouselView` shows this for ~1.5s whenever
/// `CardDeckViewModel.wrapEvent` becomes non-nil.
struct WrapIndicatorView: View {
    let event: CardDeckViewModel.WrapEvent

    private var symbolName: String {
        switch event {
        case .forward: "arrow.uturn.backward"
        case .backward: "arrow.uturn.forward"
        }
    }

    private var message: String {
        switch event {
        case .forward: "Back to the beginning"
        case .backward: "Back to the end"
        }
    }

    var body: some View {
        Label(message, systemImage: symbolName)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}
