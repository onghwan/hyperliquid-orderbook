import SwiftUI

/// Holds the app's state and the feed's lifecycle, above the screen itself.
struct RootView: View {
    @State private var model = OrderbookViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        OrderbookScreen(model: model)
            .tint(Theme.bid)
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
