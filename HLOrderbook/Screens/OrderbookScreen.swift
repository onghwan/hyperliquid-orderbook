import SwiftUI

/// The book tab: header, book, toolbar.
struct OrderbookScreen: View {
    var model: OrderbookViewModel
    @State private var showsMarketPicker = false

    var body: some View {
        VStack(spacing: 14) {
            MarketHeaderBar(model: model) { showsMarketPicker = true }
                .padding(.horizontal, 16)
            OrderbookView(model: model)
                .padding(.horizontal, 12)
            BookToolbar(model: model)
        }
        .padding(.top, 8)
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
