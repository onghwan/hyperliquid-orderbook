import Observation
import Foundation
import SwiftUI

/// What the Settings tab owns, persisted across launches.
@MainActor
@Observable
final class Preferences {
    var appearance: AppearanceMode = .dark {
        didSet {
            store.set(appearance.rawValue, forKey: Key.appearance)
        }
    }
    var hapticsEnabled: Bool {
        didSet {
            Haptics.isEnabled = hapticsEnabled
            store.set(hapticsEnabled, forKey: Key.haptics)
        }
    }

    private enum Key {
        static let haptics = "hapticsEnabled"
        static let appearance = "appearance"
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        // `object(forKey:)` rather than `bool(forKey:)`, so an unset value
        // defaults to on rather than off.
        hapticsEnabled = store.object(forKey: Key.haptics) as? Bool ?? true
        Haptics.isEnabled = hapticsEnabled
        
        let savedAppearanceString = store.string(forKey: Key.appearance) ?? ""
        appearance = AppearanceMode(rawValue: savedAppearanceString) ?? .dark
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    
    var id: Self { self }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}
