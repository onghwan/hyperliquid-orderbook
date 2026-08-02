import SwiftUI

/// Holds the app's state and the feed's lifecycle, so switching tabs never
/// tears down the socket or the book.
struct RootView: View {
    @State private var model = OrderbookViewModel()
    @State private var preferences = Preferences()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            OrderbookScreen(model: model)
                .tabItem { Label("Book", systemImage: "chart.bar.doc.horizontal") }

            SettingsScreen(preferences: preferences)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.bid)
        .preferredColorScheme(.dark)
        .task { model.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.resume()
            case .background: model.suspend()
            default: break
            }
        }
    }
}

#Preview {
    RootView()
}
