import SwiftUI

/// The composition root: owns the book's state and the feed's lifecycle, then
/// hands off to the screen. Draws nothing itself.
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
