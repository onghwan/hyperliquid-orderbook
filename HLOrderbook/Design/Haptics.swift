import UIKit

/// Pre-warmed haptic generator for user interactions. Muting is honoured
/// here so call sites don't each have to check the setting.
enum Haptics {
    /// An impact rather than `UISelectionFeedbackGenerator`, whose strength is
    /// fixed and slighter than this book wants: scrubbing the ladder should
    /// tick under the finger. `.rigid` keeps it a crisp tap rather than the
    /// duller thud of `.heavy`.
    private static let selectionGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionIntensity = 1.0

    static var isEnabled = true

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.impactOccurred(intensity: selectionIntensity)
        selectionGenerator.prepare()
    }
}
