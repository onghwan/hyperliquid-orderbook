import SwiftUI

/// Full-width bar: market selector on the left, live mark price on the right.
struct MarketHeaderBar: View {
    var model: OrderbookViewModel
    var onSelectMarket: () -> Void

    @ScaledMetric(relativeTo: .title) private var priceFontSize: CGFloat = 28
    // On the price's curve, so the two keep their proportion as text scales.
    @ScaledMetric(relativeTo: .title) private var symbolFontSize: CGFloat = 22
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
            .accessibilityLabel("Market, \(model.coin.rawValue)")
            .accessibilityHint("Choose a different market")

            Spacer()

            // Hidden rather than replaced: the row's height is what holds the
            // bar open, and the spinner's is smaller.
            priceRow
                .opacity(model.hasPrice ? 1 : 0)
                .overlay {
                    if !model.hasPrice {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.secondary)
                    }
                }
                // The last price that arrived, not the market now. The toolbar
                // says why; dimming says which numbers not to trust.
                .opacity(model.isStale ? 0.5 : 1)
                .animation(.easeOut(duration: 0.2), value: model.isStale)
                // The arrow and the colour carry the direction on screen, and
                // the dimming carries staleness. Neither survives being read
                // aloud, so the label says both.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(priceLabel)
        }
    }

    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // Always laid out, so its arrival can't resize the row.
            Image(systemName: model.priceDirection == .down ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .font(.system(size: captionFontSize))
                .foregroundStyle(priceColor)
                .opacity(model.priceDirection == .flat ? 0 : 1)
                // `offUp` clears the old triangle before raising the new one,
                // so the two directions never overlap into one shape.
                .contentTransition(.symbolEffect(.replace.offUp))
                .animation(.snappy(duration: 0.25), value: model.priceDirection)
                // Centre on the digits, not their baseline: the price's
                // cap-height centre is roughly 35% of its font size above it.
                .alignmentGuide(.firstTextBaseline) {
                    $0[VerticalAlignment.center] + priceFontSize * 0.35
                }
            // A space, not an empty string: an empty Text has no height.
            Text(model.priceText.isEmpty ? " " : model.priceText)
                .font(.system(size: priceFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(priceColor)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: model.priceText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var priceLabel: String {
        guard model.hasPrice else { return "Waiting for the price" }
        let direction = switch model.priceDirection {
        case .up: ", up"
        case .down: ", down"
        case .flat: ""
        }
        let staleness = model.isStale ? ", last known — reconnecting" : ""
        return "\(model.coin.rawValue) \(model.priceText) USDC\(direction)\(staleness)"
    }

    private var priceColor: Color {
        switch model.priceDirection {
        case .up: Theme.bid
        case .down: Theme.ask
        case .flat: .primary
        }
    }
}
