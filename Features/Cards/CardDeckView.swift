import SwiftUI

/// The "Tinder look, nothing is discarded" swipeable stack, per SPEC §5. Only
/// the top card is draggable; the next two peek behind it. Swiping left
/// advances to the next item, right returns to the previous; the deck wraps.
struct CardDeckView: View {
    let viewModel: CardDeckViewModel
    var onTapCurrentItem: (AlphabetItem) -> Void = { _ in }

    @State private var dragOffset: CGSize = .zero
    /// Which edge a freshly-inserted card slides in from — a retreat reveals
    /// the previous item with no prior on-screen identity, so without this it
    /// just fades in in place instead of sliding in from the correct side.
    @State private var insertionEdge: Edge = .trailing

    private let peekCount = 2
    private let swipeVelocityThreshold: CGFloat = 300

    /// A fixed-size window of (position, item) pairs starting at the current
    /// item — position 0 is the draggable top card, 1 and 2 peek behind it.
    /// Every card keeps the same `item.id` identity as its position changes,
    /// so advancing/retreating animates a peek card smoothly into the top
    /// slot instead of swapping out a differently-identified view.
    private var visibleEntries: [(position: Int, item: AlphabetItem)] {
        guard viewModel.count > 0 else { return [] }
        let windowSize = min(peekCount + 1, viewModel.count)
        return (0..<windowSize).map { offset in
            let index = (viewModel.currentIndex + offset) % viewModel.count
            return (position: offset, item: viewModel.order[index])
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(visibleEntries.reversed()), id: \.item.id) { entry in
                    let isTop = entry.position == 0
                    CardFaceView(item: entry.item, manifest: viewModel.manifest, allItems: viewModel.allItems, hideNames: viewModel.hideNames)
                        .scaleEffect(1 - CGFloat(entry.position) * 0.05)
                        .offset(y: CGFloat(entry.position) * 10)
                        .offset(isTop ? dragOffset : .zero)
                        .rotationEffect(isTop ? .degrees(Double(dragOffset.width / 20)) : .zero, anchor: .bottom)
                        .allowsHitTesting(isTop)
                        .gesture(dragGesture(cardWidth: geo.size.width))
                        .onTapGesture { onTapCurrentItem(entry.item) }
                        // Only the insertion gets a directional slide; a
                        // departing card is already animated by its own
                        // dragOffset fling, so a competing removal transition
                        // would fight it and produce stray diagonal motion.
                        .transition(.asymmetric(insertion: .move(edge: insertionEdge), removal: .identity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func dragGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation }
            .onEnded { value in handleDragEnd(value, cardWidth: cardWidth) }
    }

    private func handleDragEnd(_ value: DragGesture.Value, cardWidth: CGFloat) {
        let threshold = cardWidth / 3
        let velocity = value.predictedEndLocation.x - value.location.x
        if value.translation.width < -threshold || velocity < -swipeVelocityThreshold {
            swipeAway(direction: -1)
        } else if value.translation.width > threshold || velocity > swipeVelocityThreshold {
            swipeAway(direction: 1)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragOffset = .zero }
        }
    }

    /// -1 swipes left (advance to next), +1 swipes right (retreat to previous).
    private func swipeAway(direction: CGFloat) {
        insertionEdge = direction < 0 ? .trailing : .leading
        let flungOffset = CGSize(width: direction * 600, height: dragOffset.height)
        withAnimation(.easeOut(duration: 0.25)) { dragOffset = flungOffset }
        Haptics.impactLight()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                if direction < 0 { viewModel.advance() } else { viewModel.retreat() }
                dragOffset = .zero
            }
        }
    }
}
