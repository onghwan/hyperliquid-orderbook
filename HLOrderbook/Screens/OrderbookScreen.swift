import SwiftUI

/// The book fills the screen and scrolls beneath the header and the floating
/// toolbar, which are laid in as safe-area insets.
struct OrderbookScreen: View {
    var model: OrderbookViewModel
    @State private var showsMarketPicker = false

    /// Past this width there's room for bids and asks side by side. Keyed off
    /// width rather than orientation or size class: iPhones disagree about
    /// which class landscape belongs to, and iPads are wide either way.
    private static let wideThreshold: CGFloat = 600

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= Self.wideThreshold

            OrderbookView(model: model, isWide: isWide)
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 10) {
                        MarketHeaderBar(model: model) { showsMarketPicker = true }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassBackground(cornerRadius: 26)
                            .padding(.horizontal, 12)

                        columnTitles(isWide: isWide)
                            .padding(.horizontal, 20)
                            .opacity(model.hasBook ? 1 : 0)
                    }
                    .padding(.bottom, 6)
                    // Opaque: the book stops at the titles instead of showing
                    // through the header on its way up.
                    .background(Theme.background)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    BookToolbar(
                        model: model,
                        isWide: isWide,
                        bottomInset: geometry.safeAreaInsets.bottom
                    )
                }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showsMarketPicker) {
            MarketPickerSheet(model: model)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func columnTitles(isWide: Bool) -> some View {
        if isWide {
            // Mirrored to match the columns below them.
            HStack(spacing: 12) {
                BookColumnHeader(unit: model.unitLabel, layout: .leftColumn)
                BookColumnHeader(unit: model.unitLabel, layout: .rightColumn)
            }
        } else {
            BookColumnHeader(unit: model.unitLabel)
        }
    }
}

#Preview {
    OrderbookScreen(model: OrderbookViewModel())
}
