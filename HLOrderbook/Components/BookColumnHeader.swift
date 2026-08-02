import SwiftUI

/// Column titles for the book. Pinned with the market bar rather than living
/// in the scroll, so the rows pass behind them.
struct BookColumnHeader: View {
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Price (USDC)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Size (\(unit))")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Total (\(unit))")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
