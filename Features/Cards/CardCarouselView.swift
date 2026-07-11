import SwiftUI

/// The paged, peeking carousel that replaces the old swipe-to-dismiss
/// `CardDeckView`, per docs/superpowers/specs/2026-07-11-card-carousel-design.md.
/// Nothing is discarded when you swipe — paging only changes which card is
/// focused. Tapping the focused (centered) card opens its detail sheet;
/// tapping a peeking neighbor brings it into focus instead.
struct CardCarouselView: View {
    let viewModel: CardDeckViewModel
    var onTapFocusedItem: (AlphabetItem) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollTargetID: String?
    @State private var showWrapIndicator = false
    /// Suppresses the page-settle haptic for the very first `scrollTargetID`
    /// assignment in `onAppear` — that's the carousel loading, not a swipe.
    @State private var hasAppeared = false
    /// The currently live wrap-indicator dismiss timer, cancelled and
    /// replaced whenever a new wrap fires so rapid consecutive wraps never
    /// leave a stale dismiss in flight (see finding #3 in
    /// .superpowers/sdd/final-review-findings.md).
    @State private var wrapDismissTask: Task<Void, Never>?

    /// Fixed absolute size on both iPhone and iPad, per the design doc's
    /// iPad-sizing section — iPad's extra width becomes more peek instead of
    /// a bigger card.
    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 360
    private let cardSpacing: CGFloat = 16
    /// ~20% of the card width peeks in on each side at rest, per the
    /// approved visual-companion review ("moderate peek").
    private let peekFraction: CGFloat = 0.2

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: cardSpacing) {
                    ForEach(viewModel.carouselEntries) { entry in
                        CardFaceView(
                            item: entry.item, manifest: viewModel.manifest,
                            allItems: viewModel.allItems, hideNames: viewModel.hideNames
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.35)
                                .scaleEffect(phase.isIdentity ? 1 : 0.86)
                        }
                        .onTapGesture {
                            if entry.id == scrollTargetID {
                                onTapFocusedItem(entry.item)
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.focusNeighbor(entry.item)
                                }
                            }
                        }
                        .id(entry.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollTargetID)
            .safeAreaPadding(.horizontal, cardWidth * peekFraction)
            .onAppear {
                scrollTargetID = viewModel.entryID(at: viewModel.currentIndex)
                hasAppeared = true
            }
            .onChange(of: scrollTargetID) { _, newID in
                viewModel.handleScrollSettled(to: newID)
                // Matches the light-impact haptic the old swipe-to-dismiss
                // deck gave on every completed swipe (SPEC §5) — fires when
                // paging settles on a real card, not on the initial load or
                // on landing on a sentinel (the wrap indicator's own
                // `.selection()` haptic covers that case instead).
                // A wrap already gets its own `.selection()` haptic below;
                // the sentinel-to-real re-point it triggers must not also
                // fire this impact haptic (finding #2).
                if hasAppeared, let newID, newID.hasPrefix("real-"), viewModel.wrapEvent == nil {
                    Haptics.impactLight()
                }
            }
            .onChange(of: viewModel.entryID(at: viewModel.currentIndex)) { _, newID in
                if viewModel.lastIndexChangeAnimates {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scrollTargetID = newID
                    }
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        scrollTargetID = newID
                    }
                }
            }
            .onChange(of: viewModel.wrapEvent) { _, newEvent in
                guard newEvent != nil else { return }
                Haptics.selection()
                withAnimation(reduceMotion ? .easeInOut : .spring(response: 0.3, dampingFraction: 0.8)) {
                    showWrapIndicator = true
                }
                wrapDismissTask?.cancel()
                wrapDismissTask = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showWrapIndicator = false
                    }
                    viewModel.clearWrapEvent()
                }
            }

            if showWrapIndicator, let event = viewModel.wrapEvent {
                WrapIndicatorView(event: event)
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
