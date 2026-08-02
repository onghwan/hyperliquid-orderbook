import SwiftUI

/// Full-width bar: market selector on the left, live mark price on the right.
struct MarketHeaderBar: View {
    var model: OrderbookViewModel
    var onSelectMarket: () -> Void

    @ScaledMetric(relativeTo: .title) private var priceFontSize: CGFloat = 28
    @ScaledMetric(relativeTo: .headline) private var symbolFontSize: CGFloat = 19
    @ScaledMetric(relativeTo: .footnote) private var captionFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var chevronFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .headline) private var logoSize: CGFloat = 26

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelectMarket) {
                HStack(spacing: 8) {
                    Image(model.coin.iconName)
                        .resizable()
                        .frame(width: logoSize, height: logoSize)
                        .clipShape(Circle())
                    Text(model.coin.rawValue)
                        .font(.system(size: symbolFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: chevronFontSize, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // One flat baseline-aligned row: nesting the arrow and price in
            // their own HStack would hand the outer row a centre-aligned
            // baseline that shifts whenever the arrow appears.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if model.priceDirection != .flat {
                    Image(systemName: model.priceDirection == .up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: captionFontSize))
                        .foregroundStyle(priceColor)
                        // Centre the arrow on the digits instead of sitting it
                        // on their baseline: the price's cap-height centre is
                        // roughly 35% of its font size above it.
                        .alignmentGuide(.firstTextBaseline) {
                            $0[VerticalAlignment.center] + priceFontSize * 0.35
                        }
                }
                Text(model.priceText)
                    .font(.system(size: priceFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(priceColor)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: model.priceText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("USDC")
                    .font(.system(size: captionFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var priceColor: Color {
        switch model.priceDirection {
        case .up: Theme.bid
        case .down: Theme.ask
        case .flat: .primary
        }
    }
}
