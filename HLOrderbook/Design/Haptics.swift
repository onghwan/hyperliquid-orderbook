import UIKit

/// Pre-warmed haptic generator for user interactions. Muting is honoured
/// here so call sites don't each have to check the setting.
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static var isEnabled = true

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
