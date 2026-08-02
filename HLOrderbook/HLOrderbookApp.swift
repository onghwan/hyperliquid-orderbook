import SwiftUI

@main
struct HLOrderbookApp: App {
    @State private var preferences = Preferences()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // Text scales with the user's setting, but stops below the
                // accessibility sizes: past that the book's three columns no
                // longer fit side by side. Capping here rather than inside
                // the screen keeps its own @ScaledMetric values in range too.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .environment(preferences)
                .preferredColorScheme(preferences.appearance.colorScheme)
        }
    }
}
