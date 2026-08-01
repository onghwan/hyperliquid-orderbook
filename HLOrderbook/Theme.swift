import SwiftUI
import UIKit

enum Theme {
    static let background = Color(red: 0.039, green: 0.051, blue: 0.071)
    static let card = Color(red: 0.086, green: 0.106, blue: 0.137)
    static let bid = Color(red: 0.153, green: 0.780, blue: 0.545)
    static let ask = Color(red: 0.957, green: 0.318, blue: 0.400)
}

/// Pre-warmed haptic generators for user interactions.
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func lightTap() {
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }
}
