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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Seeded from the view model at init so `scrollTargetID` is never
    /// visibly wrong before layout — the actual initial scroll is then
    /// forced imperatively once real geometry is available (see the
    /// `onChange(of: geometry.size.width)` below): `scrollPosition(id:)`
    /// alone doesn't reliably move the `ScrollView` on its very first
    /// programmatic set, leaving it resting on the leading sentinel (a
    /// duplicate of the *last* item) while still reporting this state
    /// variable as if it had scrolled to the real first item.
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

    init(viewModel: CardDeckViewModel, onTapFocusedItem: @escaping (AlphabetItem) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onTapFocusedItem = onTapFocusedItem
        _scrollTargetID = State(initialValue: viewModel.entryID(at: viewModel.currentIndex))
    }

    private let cardSpacing: CGFloat = 16
    /// Preserves the original 260:360 width:height ratio so the card's
    /// proportions stay consistent now that its size is frame-relative.
    private let cardAspectRatio: CGFloat = 360.0 / 260.0
    /// The focused card's width as a fraction of the available frame width.
    /// Peek is then whatever's left over — `(frameWidth - cardWidth) / 2` on
    /// each side, by construction always symmetric and never leaving enough
    /// leftover room for a third card to sneak into view. iPad uses a larger
    /// fraction than iPhone so the focused card reads as clearly dominant
    /// instead of one of three similarly-sized cards in a row.
    private var cardWidthFraction: CGFloat {
        horizontalSizeClass == .regular ? 0.62 : 0.68
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * cardWidthFraction
            let cardHeight = cardWidth * cardAspectRatio
            let peek = max(0, (geometry.size.width - cardWidth) / 2)

            ZStack(alignment: .top) {
                ScrollViewReader { proxy in
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
                    .frame(height: cardHeight)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrollTargetID)
                    .safeAreaPadding(.horizontal, peek)
                    .onAppear {
                        hasAppeared = true
                    }
                    .onChange(of: geometry.size.width) { _, _ in
                        // `scrollPosition(id:)` alone doesn't reliably move the
                        // scroll view on its very first programmatic set (it can
                        // report the id as "current" without actually scrolling
                        // there, leaving the view resting on the leading
                        // sentinel — the *last* item — instead). Once real
                        // geometry is available, force the jump imperatively via
                        // `ScrollViewReader`, which does reliably move it.
                        if let id = viewModel.entryID(at: viewModel.currentIndex) {
                            proxy.scrollTo(id, anchor: .center)
                        }
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
                }

                if showWrapIndicator, let event = viewModel.wrapEvent {
                    WrapIndicatorView(event: event)
                        .padding(.top, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
