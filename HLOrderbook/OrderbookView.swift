import SwiftUI

enum BookSide {
    case ask, bid

    var tint: Color {
        switch self {
        case .ask: Theme.ask
        case .bid: Theme.bid
        }
    }
}

/// The book itself: asks above, spread in the middle, bids below, in a scroll
/// view initially anchored on the spread so deeper levels are a swipe away.
struct OrderbookView: View {
    var model: OrderbookViewModel
    var onCopyPrice: (String) -> Void

    // Rows track Dynamic Type, and their height grows with them so taller
    // text is never clipped.
    @ScaledMetric(relativeTo: .footnote) private var rowFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 24

    var body: some View {
        VStack(spacing: 6) {
            columnHeader

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(model.asks.reversed()) { row in
                            LevelRowView(row: row, side: .ask, fontSize: rowFontSize, height: rowHeight, onCopy: onCopyPrice)
                        }
                        SpreadRowView(spreadText: model.spreadText, percentText: model.spreadPercentText)
                            .id("spread")
                            .padding(.vertical, 4)
                        ForEach(model.bids) { row in
                            LevelRowView(row: row, side: .bid, fontSize: rowFontSize, height: rowHeight, onCopy: onCopyPrice)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.center)
                .onChange(of: model.coin) {
                    withAnimation(.snappy) {
                        proxy.scrollTo("spread", anchor: .center)
                    }
                }
            }
        }
        .overlay {
            if !model.hasBook {
                loadingOverlay
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("Price (USDC)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Size (\(model.unitLabel))")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Total (\(model.unitLabel))")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 8)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Waiting for the book…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }
}

/// A single price level. The depth bar grows from the trailing edge, and the
/// row flashes when something notable happens at that price.
struct LevelRowView: View {
    let row: OrderbookViewModel.Row
    let side: BookSide
    let fontSize: CGFloat
    let height: CGFloat
    var onCopy: (String) -> Void

    @State private var flashOpacity = 0.0

    var body: some View {
        HStack(spacing: 8) {
            Text(row.priceText)
                .foregroundStyle(side.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.sizeText)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(row.totalText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: fontSize, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 8)
        .frame(height: height)
        .background {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(side.tint.opacity(0.14))
                    .frame(width: max(0, geo.size.width * row.depth))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .animation(.easeOut(duration: 0.22), value: row.depth)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .fill(side.tint.opacity(flashOpacity))
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !row.isEmpty else { return }
            onCopy(row.rawPrice)
        }
        .onChange(of: row.flashTick) {
            flashOpacity = 0.3
            withAnimation(.easeOut(duration: 0.8)) { flashOpacity = 0 }
        }
        .opacity(row.isEmpty ? 0 : 1)
    }
}

struct SpreadRowView: View {
    let spreadText: String
    let percentText: String

    var body: some View {
        HStack(spacing: 18) {
            Text("Spread")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(spreadText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(percentText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
    }
}
