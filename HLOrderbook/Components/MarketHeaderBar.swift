import SwiftUI

/// Full-width bar: market selector on the left, live mark price on the right.
struct MarketHeaderBar: View {
    var model: OrderbookViewModel
    var onSelectMarket: () -> Void

    @ScaledMetric(relativeTo: .title) private var priceFontSize: CGFloat = 28
    // Scales on the price's curve so the two stay in proportion, but sits a
    // step below it — the price is what changes, and should lead.
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

            Spacer()

            // The price row stays in the layout while it's waiting, hidden
            // under the spinner. Swapping it out for the spinner instead
            // handed the bar the spinner's height, so the header shrank on
            // every market change and grew back when the price landed.
            priceRow
                .opacity(model.hasPrice ? 1 : 0)
                .overlay {
                    if !model.hasPrice {
                        // Stands in for the price it's waiting on, so there's
                        // one place to look rather than a dash here and a
                        // panel over the book.
                        ProgressView()
                            .controlSize(.regular)
                            // Not the accent: the price is never the thing
                            // being pointed at.
                            .tint(.secondary)
                    }
                }
        }
    }

    // One flat baseline-aligned row: nesting the arrow and price in their own
    // HStack would hand the outer row a centre-aligned baseline that shifts
    // whenever the arrow appears.
    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // Always in the layout, invisible until there's a direction to
            // show. Inserting it on the first tick would widen the row, and
            // that resize rides the price's roll animation and slides the
            // digits sideways.
            Image(systemName: model.priceDirection == .down ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .font(.system(size: captionFontSize))
                .foregroundStyle(priceColor)
                .opacity(model.priceDirection == .flat ? 0 : 1)
                // Rolls with the digits, on the price's own curve. `offUp`
                // rather than a plain replace: the old triangle clears out
                // before the new one rises, so the two directions never
                // overlap into an ambiguous shape.
                .contentTransition(.symbolEffect(.replace.offUp))
                .animation(.snappy(duration: 0.25), value: model.priceDirection)
                // Centre the arrow on the digits instead of sitting it on
                // their baseline: the price's cap-height centre is roughly
                // 35% of its font size above it.
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

    private var priceColor: Color {
        switch model.priceDirection {
        case .up: Theme.bid
        case .down: Theme.ask
        case .flat: .primary
        }
    }
}
