import UIKit

/// Thin wrapper over `UIFeedbackGenerator` — the one UIKit dependency the
/// spec explicitly allows (§1), since SwiftUI has no native haptics API.
enum Haptics {
    static func impactLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
