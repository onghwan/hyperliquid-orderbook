import SwiftUI

@main
struct HLOrderbookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Text scales with the user's setting, but stops below the
                // accessibility sizes: past that the book's three columns no
                // longer fit side by side. Capping here rather than inside
                // ContentView keeps its own @ScaledMetric values in range too.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}
