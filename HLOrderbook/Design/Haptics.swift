import UIKit

/// Pre-warmed haptic generator for user interactions. Muting is honoured
/// here so call sites don't each have to check the setting.
enum Haptics {
    /// An impact, not `UISelectionFeedbackGenerator`, whose strength is fixed
    /// and too slight to feel while scrubbing the ladder.
    private static let selectionGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionIntensity = 1.0

    static var isEnabled = true

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.impactOccurred(intensity: selectionIntensity)
        selectionGenerator.prepare()
    }
}
