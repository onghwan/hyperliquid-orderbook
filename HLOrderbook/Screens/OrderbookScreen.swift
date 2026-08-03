import SwiftUI

/// The book fills the screen and scrolls beneath the header and the floating
/// toolbar, which are laid in as safe-area insets.
struct OrderbookScreen: View {
    var model: OrderbookViewModel
    @State private var showsMarketPicker = false
    @Environment(\.colorScheme) private var colorScheme

    /// Past this width there's room for bids and asks side by side. Keyed off
    /// width rather than orientation or size class: iPhones disagree about
    /// which class landscape belongs to, and iPads are wide either way.
    private static let wideThreshold: CGFloat = 600

    /// Shared with the toolbar, so the two bars line up down both edges.
    private let sideMargin: CGFloat = 12
    private let cornerRadius: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= Self.wideThreshold

            OrderbookView(model: model, isWide: isWide)
                .safeAreaInset(edge: .top, spacing: 0) {
                    // No spacing: the titles' opaque band meets the glass, so
                    // the book has no gap to show through between the two.
                    VStack(spacing: 0) {
                        MarketHeaderBar(model: model) { showsMarketPicker = true }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            // Mirrors the toolbar: edge to edge in portrait,
                            // a rounded island in landscape.
                            .background(
                                Color.clear
                                    .glassBackground(cornerRadius: isWide ? cornerRadius : 0)
                                    .ignoresSafeArea(edges: isWide ? [] : .top)
                                    // The glass layer keeps the appearance it
                                    // was built with, so a theme change needs
                                    // it rebuilt rather than redrawn.
                                    .id(colorScheme)
                            )
                            .padding(.horizontal, isWide ? sideMargin : 0)

                        // Opaque, so the book passes behind the glass and
                        // stops here rather than muddying the titles.
                        columnTitles(isWide: isWide)
                            .padding(.horizontal, 20)
                            .opacity(model.hasBook ? 1 : 0)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                            .frame(maxWidth: .infinity)
                            .background(Theme.background)
                    }
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
            MarketPickerScreen(model: model)
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
