import Observation
import Foundation

/// What the Settings tab owns, persisted across launches.
@MainActor
@Observable
final class Preferences {
    var hapticsEnabled: Bool {
        didSet {
            Haptics.isEnabled = hapticsEnabled
            store.set(hapticsEnabled, forKey: Key.haptics)
        }
    }

    private enum Key {
        static let haptics = "hapticsEnabled"
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        // `object(forKey:)` rather than `bool(forKey:)`, so an unset value
        // defaults to on rather than off.
        hapticsEnabled = store.object(forKey: Key.haptics) as? Bool ?? true
        Haptics.isEnabled = hapticsEnabled
    }
}
