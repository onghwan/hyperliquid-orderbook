import SwiftUI

/// Column titles for the book. Pinned with the market bar rather than living
/// in the scroll, so the rows pass behind them.
struct BookColumnHeader: View {
    let unit: String
    var layout: LevelRowLayout = .ladder

    var body: some View {
        HStack(spacing: 8) {
            if layout.priceIsTrailing {
                total
                size
                price
            } else {
                price
                size
                total
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var price: some View {
        Text("Price (USDC)")
            .frame(maxWidth: .infinity, alignment: layout.priceIsTrailing ? .trailing : .leading)
    }

    private var size: some View {
        Text("Size (\(unit))")
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var total: some View {
        Text("Total (\(unit))")
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
