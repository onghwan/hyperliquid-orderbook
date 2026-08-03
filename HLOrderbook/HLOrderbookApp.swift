import SwiftUI

@main
struct HLOrderbookApp: App {
    @State private var preferences = Preferences()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // Capped below the accessibility sizes, where the book's three
                // columns stop fitting side by side. Capping at the root also
                // keeps the screen's own @ScaledMetric values in range.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .environment(preferences)
                .preferredColorScheme(preferences.appearance.colorScheme)
        }
    }
}
