import SwiftUI

/// The book tab. The book fills the screen and scrolls beneath the header
/// and the floating toolbar, which are laid in as safe-area insets.
struct OrderbookScreen: View {
    var model: OrderbookViewModel
    @State private var showsMarketPicker = false

    var body: some View {
        OrderbookView(model: model)
            .fadingTopEdge()
            .safeAreaInset(edge: .top, spacing: 0) {
                // Both pieces float on glass, so the scroll edge effect has
                // room to fade the book out on the way up — the same
                // treatment the toolbar gets at the bottom.
                VStack(spacing: 8) {
                    MarketHeaderBar(model: model) { showsMarketPicker = true }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassBackground(cornerRadius: 26)

                    BookColumnHeader(unit: model.unitLabel)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .glassBackground(cornerRadius: 16)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BookToolbar(model: model)
            }
            .background(Theme.background.ignoresSafeArea())
            .sheet(isPresented: $showsMarketPicker) {
                MarketPickerSheet(model: model)
                    .presentationDetents([.medium, .large])
            }
    }
}

#Preview {
    OrderbookScreen(model: OrderbookViewModel())
}
