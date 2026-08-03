import SwiftUI

/// What a market order sweeping down to the pinned depth would cost.
/// Values refresh in place while the popover stays open.
struct LevelStatsView: View {
    let stats: OrderbookViewModel.LevelStats?
    let coin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let stats {
                row("Distance from Mid", stats.distance)
                row("Average Price", stats.averagePrice)
                row("Total (\(coin))", stats.totalCoin)
                row("Total (USDC)", stats.totalUsdc)
            }
        }
        .padding(18)
        .frame(width: 268)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }
}
